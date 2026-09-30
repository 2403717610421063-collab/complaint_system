import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:complaint_system/models/Application.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:complaint_system/screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:complaint_system/services/email_service.dart';
import '../models/Application.dart';
import '../services/app_localizations.dart';
import '../theme/app_theme.dart';



class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  File? _pickedImage;
  String? _selectedRole;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _aadharController = TextEditingController();

  String? _selectedGender;
  String? _selectedBloodGroup;

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
  bool _loading = false;
  bool _obscurePassword = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
  }

  Future<String> getAddressFromLatLng(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      Placemark place = placemarks[0];
      return "${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}";
    } catch (e) {
      return "Address not found";
    }
  }

  double? lat, lng;
  String? _currentAddress;
  final TextEditingController _addressController = TextEditingController();
  bool _loadingLocation = false;

  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled. Please turn on GPS.')),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied.')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissions are permanently denied. Please enable in settings.')),
      );
      return;
    }
    setState(() => _loadingLocation = true);
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      Placemark p = placemarks[0];
      String formattedAddress = "${p.street}, ${p.subLocality}, ${p.locality}, ${p.postalCode}";
      setState(() { _addressController.text = formattedAddress; });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location permission or service denied.")),
      );
    } finally {
      setState(() => _loadingLocation = false);
    }
  }

  Future<String?> _uploadToCloudinary(File imageFile) async {
    try {
      String cloudName = Application.cloud_name;
      String uploadPreset = Application.complaint_img;
      final cloudinary = CloudinaryPublic(cloudName, uploadPreset, cache: false);
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(imageFile.path, resourceType: CloudinaryResourceType.Image),
      );
      print("UPLOAD SUCCESS: ${response.secureUrl}");
      return response.secureUrl;
    } catch (e) {
      print("Cloudinary Upload Error: $e");
      return null;
    }
  }

  Future<void> registerUser({
    required BuildContext context,
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
    required VoidCallback startLoading,
    required VoidCallback stopLoading,
  }) async {
    startLoading();
    try {
      UserCredential userCredential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
      String uid = userCredential.user!.uid;
      String? finalImageUrl;
      if (_pickedImage != null) { finalImageUrl = await _uploadToCloudinary(_pickedImage!); }

      double? finalLat = lat;
      double? finalLng = lng;
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        finalLat = position.latitude;
        finalLng = position.longitude;
      } catch (e) {
        debugPrint("Background location fetch failed, using previous or null");
      }

      await FirebaseFirestore.instance.collection('Users').doc(uid).set({
        'name': name,
        'email': email,
        'phone': phone,
        'dob': _dobController.text,
        'aadhar': _aadharController.text,
        'gender': _selectedGender,
        'bloodGroup': _selectedBloodGroup,
        'role': role,
        'url': finalImageUrl,
        'address': _addressController.text.trim(),
        'latitude': finalLat ?? 0.0,
        'longitude': finalLng ?? 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final emailService = EmailService();
      await emailService.sendStatusEmail(
        email,
        "Welcome to CivicConnect 🎉",
        """
        Hi $name,
        
        Your account has been successfully registered in CivicConnect.
        
        You can now:
        • Submit complaints
        • Track complaint progress
        • Provide feedback
        • Earn reward points
        
        Thank you for joining us!
        
        Regards,
        CivicConnect Team
        """,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration Successful")),
      );
      Navigator.pushReplacement(context, FadeSlideRoute(page: const LoginScreen()));

    } on FirebaseAuthException catch (e) {
      String msg = "Registration failed";
      if (e.code == 'email-already-in-use') msg = "Email already exists";
      else if (e.code == 'weak-password') msg = "Weak password";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      stopLoading();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _aadharController.dispose();
    _addressController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picFile != null) { setState(() => _pickedImage = File(picFile.path)); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [

            // ── Gradient Header ──
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded),
                onPressed: () => Navigator.pushReplacement(
                  context, FadeSlideRoute(page: const LoginScreen()),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(gradient: AppGradients.headerGradient),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.15),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                          ),
                          child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 30),
                        ),
                        const SizedBox(height: 10),
                        Text("Create Account",
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                        Text("Join Civic Connect today",
                            style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.65), fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [

                    // Section: Personal Info
                    _sectionCard(
                      title: "Personal Information",
                      icon: Icons.person_outline_rounded,
                      children: [
                        _field(_nameController,
                            label: AppLocalizations.of(context)?.translate('full_name') ?? 'Full Name',
                            icon: Icons.person_outline),
                        _gap,
                        _field(_emailController,
                            label: AppLocalizations.of(context)?.translate('email') ?? 'Email',
                            icon: Icons.email_outlined,
                            keyboard: TextInputType.emailAddress),
                        _gap,
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)?.translate('password') ?? 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        _gap,
                        _field(_phoneController,
                            label: AppLocalizations.of(context)?.translate('phone_number') ?? 'Phone Number',
                            icon: Icons.phone_outlined,
                            keyboard: TextInputType.phone),
                        _gap,
                        // Date of Birth
                        TextField(
                          controller: _dobController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)?.translate('date_of_birth') ?? 'Date of Birth',
                            prefixIcon: const Icon(Icons.calendar_today_outlined),
                          ),
                          onTap: () async {
                            DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime(2000),
                              firstDate: DateTime(1950),
                              lastDate: DateTime.now(),
                            );
                            if (pickedDate != null) {
                              setState(() {
                                _dobController.text = "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
                              });
                            }
                          },
                        ),
                        _gap,
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedGender,
                                decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context)?.translate('gender') ?? 'Gender',
                                ),
                                items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                                onChanged: (v) => setState(() => _selectedGender = v),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedBloodGroup,
                                decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context)?.translate('blood_group') ?? 'Blood Group',
                                ),
                                items: _bloodGroups.map((bg) => DropdownMenuItem(value: bg, child: Text(bg))).toList(),
                                onChanged: (v) => setState(() => _selectedBloodGroup = v),
                              ),
                            ),
                          ],
                        ),
                        _gap,
                        _field(_aadharController,
                            label: 'Aadhar Number',
                            icon: Icons.badge_outlined,
                            keyboard: TextInputType.number),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Section: Photo Upload
                    _sectionCard(
                      title: "Profile Photo",
                      icon: Icons.camera_alt_outlined,
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: _pickedImage != null ? 160 : 90,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: _pickedImage != null
                                    ? AppColors.success
                                    : AppColors.borderColor,
                                width: 2,
                                style: BorderStyle.solid,
                              ),
                              color: AppColors.surface,
                            ),
                            child: _pickedImage != null
                                ? ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.md - 2),
                              child: Image.file(_pickedImage!, fit: BoxFit.cover),
                            )
                                : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 32, color: AppColors.textSecondary),
                                const SizedBox(height: 6),
                                Text("Tap to upload photo (optional)",
                                    style: GoogleFonts.inter(
                                        fontSize: 13, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Section: Address
                    _sectionCard(
                      title: "Address",
                      icon: Icons.home_outlined,
                      children: [
                        TextFormField(
                          controller: _addressController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)?.translate('address') ?? "Home Address",
                            hintText: "Enter your address or use location",
                            prefixIcon: const Icon(Icons.home_outlined),
                            suffixIcon: _loadingLocation
                                ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                                : IconButton(
                              icon: const Icon(Icons.my_location_rounded, color: AppColors.tealDark),
                              onPressed: _getUserLocation,
                              tooltip: "Use current location",
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Section: Role
                    _sectionCard(
                      title: "Account Type",
                      icon: Icons.badge_outlined,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)?.translate('role') ?? 'Select your role',
                            prefixIcon: const Icon(Icons.group_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Citizen', child: Text('Citizen')),
                            DropdownMenuItem(value: 'Official', child: Text('Official')),
                          ],
                          onChanged: (v) => setState(() => _selectedRole = v),
                          hint: const Text('Select role'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Register Button
                    GradientButton(
                      onPressed: _loading
                          ? null
                          : () async {
                        setState(() => _loading = true);
                        await registerUser(
                          context: context,
                          name: _nameController.text.trim(),
                          email: _emailController.text.trim(),
                          password: _passwordController.text.trim(),
                          phone: _phoneController.text.trim(),
                          role: _selectedRole == "Citizen" ? "CITIZEN" : "OFFICIAL",
                          startLoading: () {},
                          stopLoading: () {},
                        );
                        if (mounted) setState(() => _loading = false);
                      },
                      child: _loading
                          ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                          : Text(
                        AppLocalizations.of(context)?.translate('register') ?? 'Create Account',
                        style: GoogleFonts.inter(
                            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),

                    const SizedBox(height: 14),

                    OutlinedButton(
                      onPressed: () => Navigator.pushReplacement(
                        context, FadeSlideRoute(page: const LoginScreen()),
                      ),
                      child: Text(
                        AppLocalizations.of(context)?.translate('have_account') ?? 'Already have an account? Login',
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget get _gap => const SizedBox(height: 14);

  Widget _field(
      TextEditingController controller, {
        required String label,
        required IconData icon,
        TextInputType? keyboard,
      }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      keyboardType: keyboard,
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}