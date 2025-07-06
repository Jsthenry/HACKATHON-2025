-- Drop existing tables if they exist (for clean setup)
DROP TABLE IF EXISTS report_updates CASCADE;
DROP TABLE IF EXISTS emergency_audio CASCADE;
DROP TABLE IF EXISTS supporting_evidence CASCADE;
DROP TABLE IF EXISTS reporter_info CASCADE;
DROP TABLE IF EXISTS reports CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;
DROP TABLE IF EXISTS companies CASCADE;

-- Drop sequence if exists
DROP SEQUENCE IF EXISTS incident_number_seq CASCADE;

-- Drop functions if they exist
DROP FUNCTION IF EXISTS generate_incident_number() CASCADE;
DROP FUNCTION IF EXISTS set_incident_number() CASCADE;
DROP FUNCTION IF EXISTS extract_company_domain(TEXT) CASCADE;
DROP FUNCTION IF EXISTS assign_company_id() CASCADE;

-- Companies table
CREATE TABLE companies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    domain TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    hsse_email TEXT,
    phone TEXT,
    address TEXT,
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User profiles table with password column for testing
CREATE TABLE profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL, -- Plain text password for testing
    full_name TEXT,
    role TEXT NOT NULL DEFAULT 'citizen' CHECK (role IN ('citizen', 'employee', 'hsse_officer', 'admin')),
    company_domain TEXT,
    phone TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Foreign key constraint
    CONSTRAINT profiles_company_domain_fkey 
        FOREIGN KEY (company_domain) REFERENCES companies(domain) ON DELETE SET NULL
);

-- Reports table
CREATE TABLE reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_number TEXT UNIQUE NOT NULL,
    report_type TEXT NOT NULL CHECK (report_type IN ('standard', 'employee', 'emergency_audio')),
    incident_type TEXT NOT NULL,
    severity_level TEXT NOT NULL CHECK (severity_level IN ('low', 'medium', 'high')),
    status TEXT NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted', 'under_review', 'investigating', 'resolved', 'closed')),
    incident_date DATE NOT NULL,
    incident_time TEXT NOT NULL,
    location_text TEXT,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    detailed_description TEXT NOT NULL,
    regulation_category TEXT,
    accident_type TEXT,
    cause_of_death TEXT,
    employee_name TEXT,
    employer_name TEXT,
    submitted_anonymously BOOLEAN DEFAULT true,
    priority_score INTEGER DEFAULT 0,
    company_id UUID REFERENCES companies(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Reporter info table
CREATE TABLE reporter_info (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
    name TEXT,
    email TEXT,
    phone TEXT,
    organization TEXT,
    is_anonymous BOOLEAN DEFAULT true,
    ip_address INET,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Supporting evidence table
CREATE TABLE supporting_evidence (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
    file_path TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_type TEXT NOT NULL CHECK (file_type IN ('image', 'video', 'document', 'other')),
    file_size BIGINT,
    mime_type TEXT,
    storage_bucket TEXT DEFAULT 'evidence-files',
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Emergency audio table
CREATE TABLE emergency_audio (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
    audio_file_path TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_size BIGINT,
    mime_type TEXT DEFAULT 'audio/aac',
    duration_seconds INTEGER DEFAULT 10,
    recording_quality TEXT DEFAULT 'standard',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Report updates table (for tracking status changes)
CREATE TABLE report_updates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
    previous_status TEXT,
    new_status TEXT NOT NULL,
    updated_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create incident number sequence
CREATE SEQUENCE incident_number_seq START WITH 1;

-- Function to generate incident numbers
CREATE OR REPLACE FUNCTION generate_incident_number()
RETURNS TEXT AS $$
BEGIN
    RETURN 'INC-' || LPAD(nextval('incident_number_seq')::TEXT, 8, '0');
END;
$$ LANGUAGE plpgsql;

-- Function to extract company domain from email
CREATE OR REPLACE FUNCTION extract_company_domain(email TEXT)
RETURNS TEXT AS $$
BEGIN
    IF email IS NULL OR email = '' OR position('@' in email) = 0 THEN
        RETURN NULL;
    END IF;
    RETURN LOWER(split_part(email, '@', 2));
END;
$$ LANGUAGE plpgsql;

-- Function to assign company ID based on reporter email or company domain
CREATE OR REPLACE FUNCTION assign_company_id()
RETURNS TRIGGER AS $$
DECLARE
    reporter_email TEXT;
    company_domain_extracted TEXT;
    company_uuid UUID;
BEGIN
    -- Skip if company_id is already set
    IF NEW.company_id IS NOT NULL THEN
        RETURN NEW;
    END IF;

    -- Try to get reporter email from reporter_info
    SELECT email INTO reporter_email 
    FROM reporter_info 
    WHERE report_id = NEW.id 
    AND email IS NOT NULL 
    LIMIT 1;

    -- Extract domain from reporter email if available
    IF reporter_email IS NOT NULL THEN
        company_domain_extracted := extract_company_domain(reporter_email);
    END IF;

    -- If no reporter email, try to extract from employee_name field (for employee reports)
    IF company_domain_extracted IS NULL AND NEW.employee_name IS NOT NULL THEN
        -- For employee reports, we might store email in employee_name
        company_domain_extracted := extract_company_domain(NEW.employee_name);
    END IF;

    -- Look up company by domain
    IF company_domain_extracted IS NOT NULL THEN
        SELECT id INTO company_uuid 
        FROM companies 
        WHERE domain = company_domain_extracted;
        
        IF company_uuid IS NOT NULL THEN
            NEW.company_id := company_uuid;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-generate incident numbers
CREATE OR REPLACE FUNCTION set_incident_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.incident_number IS NULL OR NEW.incident_number = '' THEN
        NEW.incident_number := generate_incident_number();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER set_incident_number_trigger
    BEFORE INSERT ON reports
    FOR EACH ROW
    EXECUTE FUNCTION set_incident_number();

CREATE TRIGGER assign_company_id_trigger
    AFTER INSERT ON reports
    FOR EACH ROW
    EXECUTE FUNCTION assign_company_id();

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_companies_updated_at 
    BEFORE UPDATE ON companies 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_profiles_updated_at 
    BEFORE UPDATE ON profiles 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_reports_updated_at 
    BEFORE UPDATE ON reports 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS (Row Level Security)
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE reporter_info ENABLE ROW LEVEL SECURITY;
ALTER TABLE supporting_evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE emergency_audio ENABLE ROW LEVEL SECURITY;
ALTER TABLE report_updates ENABLE ROW LEVEL SECURITY;

-- RLS Policies for testing (allow all access for anonymous and authenticated users)
-- CREATE POLICY "reports_allow_all" ON reports
--     FOR ALL TO anon, authenticated
--     USING (true)
--     WITH CHECK (true);

-- Add this policy for HSSE officers:
CREATE POLICY "hsse_officer_can_view_company_reports" ON reports
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE
                profiles.email = current_setting('request.jwt.claim.email', true)
                AND profiles.role = 'hsse_officer'
                AND profiles.company_domain IS NOT NULL
                AND reports.company_id = (
                    SELECT id FROM companies WHERE domain = profiles.company_domain
                )
        )
        OR
        EXISTS (
            SELECT 1 FROM profiles
            WHERE
                profiles.email = current_setting('request.jwt.claim.email', true)
                AND profiles.role = 'admin'
        )
    );

-- Optionally, allow report creators to see their own reports:
CREATE POLICY "report_creator_can_view_own" ON reports
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM reporter_info
            WHERE
                reporter_info.report_id = reports.id
                AND reporter_info.email = current_setting('request.jwt.claim.email', true)
        )
    );

CREATE POLICY "companies_allow_all" ON companies
    FOR ALL TO anon, authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "profiles_allow_all" ON profiles
    FOR ALL TO anon, authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "reporter_info_allow_all" ON reporter_info
    FOR ALL TO anon, authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "supporting_evidence_allow_all" ON supporting_evidence
    FOR ALL TO anon, authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "emergency_audio_allow_all" ON emergency_audio
    FOR ALL TO anon, authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "report_updates_allow_all" ON report_updates
    FOR ALL TO anon, authenticated
    USING (true)
    WITH CHECK (true);

-- Insert sample companies
INSERT INTO companies (domain, name, hsse_email, phone, address) VALUES 
('exxonmobil.com', 'ExxonMobil Guyana', 'hsse@exxonmobil.com', '+592-225-1234', 'Georgetown, Guyana'),
('hessguyana.com', 'Hess Guyana', 'safety@hessguyana.com', '+592-225-5678', 'Georgetown, Guyana'),
('totalenergies.com', 'TotalEnergies Guyana', 'hsse@totalenergies.com', '+592-225-9012', 'Georgetown, Guyana'),
('gov.gy', 'Government of Guyana', 'safety@gov.gy', '+592-226-1234', 'Georgetown, Guyana'),
('cnoocnexen.com', 'CNOOC Nexen', 'hsse@cnoocnexen.com', '+592-225-3456', 'Georgetown, Guyana'),
('esso.com', 'Esso Exploration and Production Guyana', 'safety@esso.com', '+592-225-7890', 'Georgetown, Guyana');

-- Insert test users with plain text passwords
INSERT INTO profiles (email, password, full_name, role, company_domain, phone, is_active) VALUES 
-- System Administrator
('admin@hsseportal.gov.gy', 'HSSEAdmin2024!', 'System Administrator', 'admin', 'gov.gy', '+592-226-1111', true),

-- ExxonMobil Users
('john.doe@exxonmobil.com', 'Employee123!', 'John Doe', 'employee', 'exxonmobil.com', '+592-225-1100', true),
('sarah.wilson@exxonmobil.com', 'HSSE123!', 'Sarah Wilson', 'hsse_officer', 'exxonmobil.com', '+592-225-1101', true),
('mike.johnson@exxonmobil.com', 'Employee123!', 'Mike Johnson', 'employee', 'exxonmobil.com', '+592-225-1102', true),

-- Hess Guyana Users
('jane.smith@hessguyana.com', 'HSSE123!', 'Jane Smith', 'hsse_officer', 'hessguyana.com', '+592-225-5601', true),
('david.brown@hessguyana.com', 'Employee123!', 'David Brown', 'employee', 'hessguyana.com', '+592-225-5602', true),
('lisa.garcia@hessguyana.com', 'HSSE123!', 'Lisa Garcia', 'hsse_officer', 'hessguyana.com', '+592-225-5603', true),

-- TotalEnergies Users
('safety.manager@totalenergies.com', 'Safety123!', 'Pierre Dubois', 'hsse_officer', 'totalenergies.com', '+592-225-9001', true),
('marie.bernard@totalenergies.com', 'Employee123!', 'Marie Bernard', 'employee', 'totalenergies.com', '+592-225-9002', true),

-- CNOOC Nexen Users
('alex.chen@cnoocnexen.com', 'HSSE123!', 'Alex Chen', 'hsse_officer', 'cnoocnexen.com', '+592-225-3401', true),
('robert.kim@cnoocnexen.com', 'Employee123!', 'Robert Kim', 'employee', 'cnoocnexen.com', '+592-225-3402', true),

-- Esso Users
('carlos.rodriguez@esso.com', 'HSSE123!', 'Carlos Rodriguez', 'hsse_officer', 'esso.com', '+592-225-7801', true),
('anna.petrova@esso.com', 'Employee123!', 'Anna Petrova', 'employee', 'esso.com', '+592-225-7802', true),

-- Government Users
('ministry.natural@gov.gy', 'Gov123!', 'Ministry of Natural Resources', 'hsse_officer', 'gov.gy', '+592-226-1200', true),
('epa.officer@gov.gy', 'Gov123!', 'EPA Officer', 'hsse_officer', 'gov.gy', '+592-226-1201', true),

-- Citizen Users (no company affiliation)
('citizen1@gmail.com', 'Citizen123!', 'Regular Citizen', 'citizen', NULL, '+592-600-1001', true),
('concerned.resident@yahoo.com', 'Citizen123!', 'Concerned Resident', 'citizen', NULL, '+592-600-1002', true);

-- Insert sample reports for testing
INSERT INTO reports (
    report_type, incident_type, severity_level, status, incident_date, incident_time,
    location_text, latitude, longitude, detailed_description, submitted_anonymously,
    priority_score, company_id
) VALUES 
-- ExxonMobil Reports
(
    'employee', 
    'Equipment Failure', 
    'high', 
    'under_review', 
    '2024-01-15', 
    '14:30',
    'Liza Unity FPSO, Deck 3, Pump Room A',
    6.8013,
    -58.1551,
    'High pressure pump failure in the oil processing unit. Automatic shutdown systems activated. No injuries reported but production temporarily halted. Preliminary investigation suggests bearing failure due to excessive vibration.',
    false,
    85,
    (SELECT id FROM companies WHERE domain = 'exxonmobil.com')
),
(
    'employee',
    'Near Miss',
    'medium',
    'investigating',
    '2024-01-20',
    '09:15',
    'Liza Unity FPSO, Helideck',
    6.8013,
    -58.1551,
    'During helicopter landing operations, a loose cargo net was spotted near the helideck perimeter. Operations were immediately suspended and the area secured. Weather conditions were within normal parameters.',
    false,
    55,
    (SELECT id FROM companies WHERE domain = 'exxonmobil.com')
),

-- Hess Guyana Reports
(
    'employee',
    'Workplace Injury',
    'medium',
    'resolved',
    '2024-01-18',
    '11:45',
    'Payara Development, Construction Vessel, Welding Area',
    6.7950,
    -58.1650,
    'Welder sustained minor burns on left hand during routine welding operations. First aid administered immediately. Worker transported to medical facility for further evaluation. All safety protocols were followed.',
    false,
    60,
    (SELECT id FROM companies WHERE domain = 'hessguyana.com')
),

-- TotalEnergies Reports
(
    'employee',
    'Environmental Spill',
    'high',
    'investigating',
    '2024-01-22',
    '16:20',
    'Kaieteur Block, Drilling Platform Alpha',
    6.5000,
    -58.5000,
    'Minor hydraulic fluid spill (approximately 50 liters) during drilling operations. Spill contained using onboard response equipment. No environmental impact detected. Root cause investigation ongoing.',
    false,
    80,
    (SELECT id FROM companies WHERE domain = 'totalenergies.com')
),

-- Citizen Reports
(
    'standard',
    'Environmental Concern',
    'medium',
    'submitted',
    '2024-01-25',
    '07:30',
    'Georgetown Harbor, near Kingston Seawall',
    6.8000,
    -58.1667,
    'Observed unusual foam and discoloration in harbor water near industrial area. Strong chemical odor present. Multiple dead fish spotted floating. Local fishing community concerned about water quality.',
    true,
    65,
    NULL
),
(
    'standard',
    'Safety Violation',
    'high',
    'under_review',
    '2024-01-28',
    '12:00',
    'Demerara River, Offshore Supply Vessel Transit',
    6.7500,
    -58.2000,
    'Supply vessel observed operating at excessive speed in restricted zone near fishing areas. No proper warning signals given. Created dangerous wake conditions for smaller fishing boats in the area.',
    true,
    75,
    NULL
),

-- Emergency Audio Report
(
    'emergency_audio',
    'Emergency Situation',
    'high',
    'investigating',
    '2024-01-30',
    '03:45',
    'Stabroek Block, Emergency Location',
    6.8500,
    -58.3000,
    'Emergency audio report automatically generated. 10-second audio recording captured. GPS coordinates logged. Immediate response protocols activated.',
    true,
    95,
    NULL
);

-- Insert corresponding reporter info
INSERT INTO reporter_info (report_id, name, email, phone, organization, is_anonymous) VALUES
-- Employee reports (not anonymous)
(
    (SELECT id FROM reports WHERE incident_type = 'Equipment Failure' LIMIT 1),
    'John Doe',
    'john.doe@exxonmobil.com',
    '+592-225-1100',
    'ExxonMobil Guyana',
    false
),
(
    (SELECT id FROM reports WHERE incident_type = 'Near Miss' LIMIT 1),
    'Sarah Wilson',
    'sarah.wilson@exxonmobil.com',
    '+592-225-1101',
    'ExxonMobil Guyana',
    false
),
(
    (SELECT id FROM reports WHERE incident_type = 'Workplace Injury' LIMIT 1),
    'David Brown',
    'david.brown@hessguyana.com',
    '+592-225-5602',
    'Hess Guyana',
    false
),
(
    (SELECT id FROM reports WHERE incident_type = 'Environmental Spill' LIMIT 1),
    'Pierre Dubois',
    'safety.manager@totalenergies.com',
    '+592-225-9001',
    'TotalEnergies Guyana',
    false
),
-- Citizen reports (anonymous)
(
    (SELECT id FROM reports WHERE incident_type = 'Environmental Concern' LIMIT 1),
    NULL,
    NULL,
    NULL,
    NULL,
    true
),
(
    (SELECT id FROM reports WHERE incident_type = 'Safety Violation' LIMIT 1),
    NULL,
    NULL,
    NULL,
    NULL,
    true
),
-- Emergency report (anonymous)
(
    (SELECT id FROM reports WHERE incident_type = 'Emergency Situation' LIMIT 1),
    NULL,
    NULL,
    NULL,
    NULL,
    true
);

-- Create indexes for better performance
CREATE INDEX idx_reports_company_id ON reports(company_id);
CREATE INDEX idx_reports_status ON reports(status);
CREATE INDEX idx_reports_severity_level ON reports(severity_level);
CREATE INDEX idx_reports_report_type ON reports(report_type);
CREATE INDEX idx_reports_created_at ON reports(created_at);
CREATE INDEX idx_reports_incident_date ON reports(incident_date);
CREATE INDEX idx_reports_incident_number ON reports(incident_number);
CREATE INDEX idx_reports_priority_score ON reports(priority_score);
CREATE INDEX idx_reports_location ON reports USING GIST(ll_to_earth(latitude, longitude)) WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

CREATE INDEX idx_profiles_company_domain ON profiles(company_domain);
CREATE INDEX idx_profiles_role ON profiles(role);
CREATE INDEX idx_profiles_email ON profiles(email);
CREATE INDEX idx_profiles_is_active ON profiles(is_active);

CREATE INDEX idx_companies_domain ON companies(domain);

CREATE INDEX idx_reporter_info_report_id ON reporter_info(report_id);
CREATE INDEX idx_reporter_info_email ON reporter_info(email);

CREATE INDEX idx_supporting_evidence_report_id ON supporting_evidence(report_id);
CREATE INDEX idx_supporting_evidence_file_type ON supporting_evidence(file_type);

CREATE INDEX idx_emergency_audio_report_id ON emergency_audio(report_id);

CREATE INDEX idx_report_updates_report_id ON report_updates(report_id);
CREATE INDEX idx_report_updates_updated_by ON report_updates(updated_by);
CREATE INDEX idx_report_updates_created_at ON report_updates(created_at);

-- Create view for easy report querying with company information
CREATE VIEW reports_with_company AS
SELECT 
    r.*,
    c.name as company_name,
    c.domain as company_domain,
    c.hsse_email as company_hsse_email,
    ri.name as reporter_name,
    ri.email as reporter_email,
    ri.phone as reporter_phone,
    ri.organization as reporter_organization,
    CASE 
        WHEN r.priority_score >= 80 THEN 'Critical'
        WHEN r.priority_score >= 60 THEN 'High'
        WHEN r.priority_score >= 40 THEN 'Medium'
        ELSE 'Low'
    END as priority_level
FROM reports r
LEFT JOIN companies c ON r.company_id = c.id
LEFT JOIN reporter_info ri ON r.id = ri.report_id;

-- Grant permissions on the view
GRANT SELECT ON reports_with_company TO anon, authenticated;

-- Create function to get reports by company domain
CREATE OR REPLACE FUNCTION get_reports_by_company_domain(domain_name TEXT)
RETURNS TABLE(
    id UUID,
    incident_number TEXT,
    report_type TEXT,
    incident_type TEXT,
    severity_level TEXT,
    status TEXT,
    incident_date DATE,
    incident_time TEXT,
    location_text TEXT,
    latitude DECIMAL,
    longitude DECIMAL,
    detailed_description TEXT,
    priority_score INTEGER,
    company_name TEXT,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.id,
        r.incident_number,
        r.report_type,
        r.incident_type,
        r.severity_level,
        r.status,
        r.incident_date,
        r.incident_time,
        r.location_text,
        r.latitude,
        r.longitude,
        r.detailed_description,
        r.priority_score,
        c.name as company_name,
        r.created_at
    FROM reports r
    LEFT JOIN companies c ON r.company_id = c.id
    WHERE c.domain = domain_name OR (domain_name IS NULL AND c.domain IS NULL)
    ORDER BY r.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Create function to get dashboard statistics
CREATE OR REPLACE FUNCTION get_dashboard_stats()
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'total_reports', (SELECT COUNT(*) FROM reports),
        'citizen_reports', (SELECT COUNT(*) FROM reports WHERE report_type = 'standard'),
        'employee_reports', (SELECT COUNT(*) FROM reports WHERE report_type = 'employee'),
        'emergency_reports', (SELECT COUNT(*) FROM reports WHERE report_type = 'emergency_audio'),
        'high_priority', (SELECT COUNT(*) FROM reports WHERE severity_level = 'high'),
        'pending_reports', (SELECT COUNT(*) FROM reports WHERE status IN ('submitted', 'under_review')),
        'resolved_reports', (SELECT COUNT(*) FROM reports WHERE status = 'resolved'),
        'active_companies', (SELECT COUNT(*) FROM companies),
        'active_users', (SELECT COUNT(*) FROM profiles WHERE is_active = true),
        'reports_last_30_days', (SELECT COUNT(*) FROM reports WHERE created_at >= NOW() - INTERVAL '30 days')
    ) INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Show completion message
DO $$
BEGIN
    RAISE NOTICE '✅ HSSE Database setup completed successfully!';
    RAISE NOTICE '📊 Sample data inserted:';
    RAISE NOTICE '   - % companies', (SELECT COUNT(*) FROM companies);
    RAISE NOTICE '   - % users', (SELECT COUNT(*) FROM profiles);
    RAISE NOTICE '   - % reports', (SELECT COUNT(*) FROM reports);
    RAISE NOTICE '🔐 Test login credentials created';
    RAISE NOTICE '🚀 Database ready for HSSE Portal application';
END $$;
