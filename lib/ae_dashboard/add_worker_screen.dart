import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/field_worker_model.dart';

class AddWorkerScreen extends StatefulWidget {
  const AddWorkerScreen({super.key});

  @override
  State<AddWorkerScreen> createState() => _AddWorkerScreenState();
}

class _AddWorkerScreenState extends State<AddWorkerScreen> {

  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedRole = 'Lineman';
  String _selectedWard = '52';

  final List<String> _roles = [
    'Foreman',
    'Lineman',
  ];

  final List<String> _wards = ['52', '53', '54'];

  Future<void> _saveWorker() async {

    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      return;
    }

    final worker = FieldWorkerModel(
      id: '',
      name: _nameController.text.trim(),
      officialRole: _selectedRole,
      role: 'FIELD_WORKER',
      section: 'Peelamedu Section',
      contact: _contactController.text.trim(),
      ward: _selectedWard,
      status: 'free',
      activeJobs: 0,
      maxJobs: 3,
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    // Store manually-added workers as user documents so that they
    // participate in the same routing model as auto-seeded workers.
    await FirebaseFirestore.instance
        .collection('Users')
        .add(worker.toMap());

    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Register New Field Staff"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16.0),

        child: Column(
          children: [

            /// Worker Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Worker Full Name",
              ),
            ),

            const SizedBox(height: 15),

            /// Email
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "Worker Email",
              ),
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: 15),

            /// Password
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: "Temporary Password",
              ),
              obscureText: true,
            ),

            const SizedBox(height: 15),

            /// Role
            DropdownButtonFormField<String>(
              initialValue: _selectedRole,
              items: _roles
                  .map((r) => DropdownMenuItem(
                value: r,
                child: Text(r),
              ))
                  .toList(),
              onChanged: (val) => setState(() => _selectedRole = val!),
              decoration: const InputDecoration(
                labelText: "Designated Role",
              ),
            ),

            const SizedBox(height: 15),

            /// Ward
            DropdownButtonFormField<String>(
              initialValue: _selectedWard,
              items: _wards
                  .map((w) => DropdownMenuItem(
                value: w,
                child: Text('Ward $w'),
              ))
                  .toList(),
              onChanged: (val) => setState(() => _selectedWard = val ?? '52'),
              decoration: const InputDecoration(
                labelText: "Assigned Ward",
              ),
            ),

            const SizedBox(height: 15),

            /// Contact
            TextField(
              controller: _contactController,
              decoration: const InputDecoration(
                labelText: "Contact Number",
              ),
              keyboardType: TextInputType.phone,
            ),

            const Spacer(),

            /// Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveWorker,
                child: const Text("Add to Section Staff"),
              ),
            ),

          ],
        ),
      ),
    );
  }
}