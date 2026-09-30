import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:complaint_system/models/Application.dart';
import 'package:complaint_system/services/officer_management_service.dart';

class CreateOfficialScreen extends StatefulWidget {
  const CreateOfficialScreen({super.key});

  @override
  State<CreateOfficialScreen> createState() => _CreateOfficialScreenState();
}

class _CreateOfficialScreenState extends State<CreateOfficialScreen> {
  static const _purple = Color(0xFF7B2FBE);
  static const _purpleDark = Color(0xFF4A1680);
  static const _surface = Color(0xFFF5F1FA);
  static const _card = Colors.white;

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _officerNumberController = TextEditingController();

  String? _selectedGender;
  String? _selectedBloodGroup;
  String? _selectedRole;

  File? _imageFile;

  bool _loading = false;
  bool _gettingLocation = false;
  bool _obscurePassword = true;

  static const List<String> _genders = ['Male', 'Female', 'Other'];
  static const List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  static const List<String> _roles = ['AE', 'AEE', 'EE','Foreman','Lineman'];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _aadhaarController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _officerNumberController.dispose();
    super.dispose();
  }

  // LOCATION
  Future<void> _getCurrentLocation() async {
    setState(() => _gettingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark p = placemarks.first;
        _addressController.text = "${p.street}, ${p.locality}, ${p.postalCode}";
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar("Location error: $e");
    }

    setState(() => _gettingLocation = false);
  }

  // IMAGE PICKER
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // CLOUDINARY UPLOAD
  Future<String?> _uploadToCloudinary(File imageFile) async {
    try {
      final cloudinary = CloudinaryPublic(
        Application.cloud_name,
        Application.complaint_img,
        cache: false,
      );

      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(imageFile.path),
      );

      return response.secureUrl;
    } catch (e) {
      debugPrint("Cloudinary Error: $e");
      return null;
    }
  }

  // CREATE ACCOUNT
  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate role selection only
    if (_selectedRole == null) {
      _showSnackBar("Please select a role", isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      String? imageUrl;

      if (_imageFile != null) {
        imageUrl = await _uploadToCloudinary(_imageFile!);
      }

      final secondaryApp = await Firebase.initializeApp(
        name: "Admin_${DateTime.now().millisecondsSinceEpoch}",
        options: Firebase.app().options,
      );

      final credential = await FirebaseAuth.instanceFor(app: secondaryApp)
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      String uid = credential.user!.uid;

      // Save to Firestore without jurisdiction checks
      await FirebaseFirestore.instance.collection('Users').doc(uid).set({
        'uid': uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'dob': _dobController.text.trim(),
        'gender': _selectedGender,
        'bloodGroup': _selectedBloodGroup,
        'aadhaar': _aadhaarController.text.trim(),
        'address': _addressController.text.trim(),
        'officialRole': _selectedRole,
        'section_id': _officerNumberController.text.trim(),
        'url': imageUrl ?? "",
        'role': 'OFFICIAL',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await secondaryApp.delete();

      if (!mounted) return;
      _showSnackBar("Official Registered Successfully", isError: false);
      _resetForm();

    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString());
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  String _getDynamicIdLabel() {
    switch (_selectedRole?.trim()) {
      case 'AE':
      case 'Foreman':
      case 'Lineman':
        return "Section No.";
      case 'AEE':
        return "Subdivision ID";
      case 'EE':
        return "Division ID";
      default:
        return "Officer ID."; // Fallback label if nothing is selected
    }
  }

  void _resetForm() {
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _dobController.clear();
    _aadhaarController.clear();
    _addressController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _officerNumberController.clear();

    setState(() {
      _selectedGender = null;
      _selectedBloodGroup = null;
      _selectedRole = null;
      _imageFile = null;
      _obscurePassword = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: Text(
          "Register Official",
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: _card,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 14),
              _buildSectionCard(
                icon: Icons.badge_rounded,
                title: 'Identity',
                subtitle: 'Core profile details for the official',
                children: [
                  _buildImagePicker(),
                  const SizedBox(height: 16),
                  _buildField(_nameController, "Full Name", Icons.person),
                  const SizedBox(height: 12),
                  _buildField(
                    _emailController,
                    "Email",
                    Icons.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          _phoneController,
                          "Phone",
                          Icons.phone,
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _buildDateField()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          "Gender",
                          _genders,
                          _selectedGender,
                              (v) => setState(() => _selectedGender = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDropdown(
                          "Blood",
                          _bloodGroups,
                          _selectedBloodGroup,
                              (v) => setState(() => _selectedBloodGroup = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    _addressController,
                    "Address",
                    Icons.home,
                    suffix: _gettingLocation
                        ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : IconButton(
                      icon: const Icon(Icons.my_location),
                      onPressed: _getCurrentLocation,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    _aadhaarController,
                    "Aadhaar Number",
                    Icons.fingerprint,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildSectionCard(
                icon: Icons.account_tree_rounded,
                title: 'Role & Jurisdiction',
                subtitle: 'Assign level and service boundary',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown("Role", _roles, _selectedRole, (v) {
                          setState(() {
                            _selectedRole = v;
                            _officerNumberController.clear();
                          });
                        }),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildField(
                          _officerNumberController,
                          _getDynamicIdLabel(),
                          Icons.badge,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildSectionCard(
                icon: Icons.lock_rounded,
                title: 'Security',
                subtitle: 'Set initial credentials for login',
                children: [
                  _buildField(
                    _passwordController,
                    "Password",
                    Icons.lock,
                    obscureText: _obscurePassword,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    _confirmPasswordController,
                    "Confirm Password",
                    Icons.lock_clock,
                    obscureText: true,
                    validator: (v) {
                      if (v != _passwordController.text) return "Passwords do not match";
                      if (v!.isEmpty) return "Required";
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_purple, _purpleDark],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _purple.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _createAccount,
                    icon: const Icon(Icons.how_to_reg_rounded, color: Colors.white),
                    label: Text(
                      "REGISTER OFFICIAL",
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_purple, _purpleDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.verified_user_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New Official Onboarding',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create role, jurisdiction and secure login in one flow.',
                  style: GoogleFonts.nunito(
                    color: Colors.white.withOpacity(0.88),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A1680).withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0E7FB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _purple, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E0A3C),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Center(
        child: Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE9D8FD), width: 2),
            gradient: _imageFile == null
                ? const LinearGradient(
              colors: [Color(0xFFF4EAFE), Color(0xFFEDE4F8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : null,
            image: _imageFile != null
                ? DecorationImage(
              image: FileImage(_imageFile!),
              fit: BoxFit.cover,
            )
                : null,
          ),
          child: _imageFile == null
              ? const Icon(Icons.add_a_photo_rounded, size: 30, color: _purple)
              : null,
        ),
      ),
    );
  }

  Widget _buildField(
      TextEditingController controller,
      String label,
      IconData icon, {
        bool obscureText = false,
        Widget? suffix,
        String? Function(String?)? validator,
        TextInputType? keyboardType,
        int? maxLines = 1,
      }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: obscureText ? 1 : maxLines,
      validator: validator ?? (v) => v!.isEmpty ? "Required" : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.nunito(
          color: const Color(0xFF64748B),
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFFAF7FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2D5F6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2D5F6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _purple, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return TextFormField(
      controller: _dobController,
      readOnly: true,
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime(1995),
          firstDate: DateTime(1950),
          lastDate: DateTime.now(),
        );

        if (picked != null) {
          _dobController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
        }
      },
      validator: (v) => v!.isEmpty ? "Required" : null,
      decoration: InputDecoration(
        labelText: "DOB",
        labelStyle: GoogleFonts.nunito(
          color: const Color(0xFF64748B),
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: const Icon(Icons.calendar_today),
        filled: true,
        fillColor: const Color(0xFFFAF7FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2D5F6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2D5F6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _purple, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildDropdown(
      String label,
      List<String> items,
      String? value,
      Function(String?) onChanged,
      ) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? "Required" : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.nunito(
          color: const Color(0xFF64748B),
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: const Color(0xFFFAF7FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2D5F6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2D5F6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _purple, width: 1.4),
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }
}