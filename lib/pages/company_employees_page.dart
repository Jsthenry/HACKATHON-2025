import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/responsive_wrapper.dart';

class CompanyEmployeesPage extends StatefulWidget {
  final String companyDomain;

  const CompanyEmployeesPage({super.key, required this.companyDomain});

  @override
  State<CompanyEmployeesPage> createState() => _CompanyEmployeesPageState();
}

class _CompanyEmployeesPageState extends State<CompanyEmployeesPage> {
  final _searchController = TextEditingController();
  String _selectedFilter = 'all';

  // Mock data
  final List<Map<String, dynamic>> _employees = [
    {
      'id': 'EMP001',
      'name': 'John Doe',
      'email': 'john.doe@${DateTime.now().millisecondsSinceEpoch}.com',
      'role': 'employee',
      'status': 'active',
      'joinDate': DateTime.now().subtract(const Duration(days: 120)),
    },
    {
      'id': 'EMP002',
      'name': 'Jane Smith',
      'email': 'jane.smith@${DateTime.now().millisecondsSinceEpoch}.com',
      'role': 'hsse_officer',
      'status': 'active',
      'joinDate': DateTime.now().subtract(const Duration(days: 90)),
    },
    {
      'id': 'EMP003',
      'name': 'Mike Johnson',
      'email': 'mike.johnson@${DateTime.now().millisecondsSinceEpoch}.com',
      'role': 'employee',
      'status': 'inactive',
      'joinDate': DateTime.now().subtract(const Duration(days: 200)),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: [
          _buildHeader(),
          _buildFilters(),
          Expanded(child: _buildEmployeesList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEmployeeDialog(),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        icon: Icon(Icons.person_add),
        label: Text('Add Employee'),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search employees...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.lightGrey),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.filter_list),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('All', 'all'),
          _buildFilterChip('Active', 'active'),
          _buildFilterChip('HSSE Officers', 'hsse_officer'),
          _buildFilterChip('Employees', 'employee'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = value;
          });
        },
        backgroundColor: Colors.white,
        selectedColor: AppColors.primaryBlue.withOpacity(0.2),
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildEmployeesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _employees.length,
      itemBuilder: (context, index) {
        final employee = _employees[index];
        return _buildEmployeeCard(employee);
      },
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> employee) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
            child: Text(
              employee['name'].toString().split(' ').map((n) => n[0]).take(2).join(),
              style: TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee['name'],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  employee['email'],
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: employee['role'] == 'hsse_officer' 
                            ? AppColors.primaryBlue.withOpacity(0.1)
                            : AppColors.successGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        employee['role'] == 'hsse_officer' ? 'HSSE Officer' : 'Employee',
                        style: TextStyle(
                          fontSize: 12,
                          color: employee['role'] == 'hsse_officer' 
                              ? AppColors.primaryBlue
                              : AppColors.successGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: employee['status'] == 'active' 
                            ? AppColors.successGreen
                            : AppColors.mediumGrey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      employee['status'] == 'active' ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton(
            icon: Icon(Icons.more_vert, color: AppColors.mediumGrey),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: Text('Edit'),
                onTap: () => _editEmployee(employee),
              ),
              PopupMenuItem(
                child: Text('View Details'),
                onTap: () => _viewEmployeeDetails(employee),
              ),
              PopupMenuItem(
                child: Text(
                  employee['status'] == 'active' ? 'Deactivate' : 'Activate',
                ),
                onTap: () => _toggleEmployeeStatus(employee),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddEmployeeDialog() {
    // Reuse the AddEmployeeDialog from company_hsse_page.dart
    showDialog(
      context: context,
      builder: (context) => AddEmployeeDialog(companyDomain: widget.companyDomain),
    );
  }

  void _editEmployee(Map<String, dynamic> employee) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Edit ${employee["name"]} - Coming soon!')),
    );
  }

  void _viewEmployeeDetails(Map<String, dynamic> employee) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('View details for ${employee["name"]} - Coming soon!')),
    );
  }

  void _toggleEmployeeStatus(Map<String, dynamic> employee) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${employee["name"]} status toggled - Coming soon!'),
        backgroundColor: AppColors.warningOrange,
      ),
    );
  }
}

// Import the AddEmployeeDialog from company_hsse_page.dart
class AddEmployeeDialog extends StatefulWidget {
  final String companyDomain;

  const AddEmployeeDialog({super.key, required this.companyDomain});

  @override
  State<AddEmployeeDialog> createState() => _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends State<AddEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'employee';
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Auto-generate a default password
    _generateDefaultPassword();
  }

  void _generateDefaultPassword() {
    // Generate a simple default password (company name + 123)
    final companyName = widget.companyDomain.split('.')[0];
    _passwordController.text = '${companyName}123';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxHeight: 600),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_add, color: AppColors.primaryBlue),
                    const SizedBox(width: 8),
                    Text(
                      'Add Employee',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  validator: (value) => value?.isEmpty == true ? 'Name is required' : null,
                ),
                
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email Address *',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    helperText: 'Employee will use this email to log in',
                  ),
                  validator: (value) {
                    if (value?.isEmpty == true) return 'Email is required';
                    if (!value!.contains('@')) return 'Enter valid email';
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Default Password *',
                    prefixIcon: Icon(Icons.lock_outline),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                        ),
                        IconButton(
                          onPressed: _generateDefaultPassword,
                          icon: Icon(Icons.refresh),
                          tooltip: 'Generate new password',
                        ),
                      ],
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    helperText: 'Employee will be prompted to change on first login',
                  ),
                  validator: (value) {
                    if (value?.isEmpty == true) return 'Password is required';
                    if (value!.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  'Role *',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.lightGrey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text('Employee'),
                        subtitle: const Text('Standard employee access'),
                        value: 'employee',
                        groupValue: _selectedRole,
                        onChanged: (value) => setState(() => _selectedRole = value!),
                      ),
                      Divider(height: 1),
                      RadioListTile<String>(
                        title: const Text('HSSE Officer'),
                        subtitle: const Text('HSSE management access'),
                        value: 'hsse_officer',
                        groupValue: _selectedRole,
                        onChanged: (value) => setState(() => _selectedRole = value!),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Login credentials preview
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.infoBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.infoBlue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: AppColors.infoBlue, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Employee Login Credentials',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.infoBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Email: ${_emailController.text.isNotEmpty ? _emailController.text : 'Enter email above'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Password: ${_passwordController.text}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Employee will be required to change password on first login',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.warningOrange,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _addEmployee,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Add Employee'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addEmployee() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.pop(context);
      
      // Show success message with login details
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.successGreen),
              const SizedBox(width: 8),
              Text('Employee Added'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_nameController.text} has been added as ${_selectedRole == "employee" ? "Employee" : "HSSE Officer"}.'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lightGrey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Login Credentials:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Email: ${_emailController.text}'),
                    Text('Password: ${_passwordController.text}'),
                    const SizedBox(height: 8),
                    Text(
                      'Employee must change password on first login',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.warningOrange,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
