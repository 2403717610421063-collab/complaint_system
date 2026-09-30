import 'dart:io';
import 'package:complaint_system/models/Application.dart' ;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:complaint_system/models/Application.dart';
import '../models/Application.dart' ;
import '../models/Application.dart' ;
import '../services/app_localizations.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  String? _selectedBloodGroup;

  File? _newImage;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userData['name']);
    _phoneController = TextEditingController(text: widget.userData['phone']);
    _addressController = TextEditingController(text: widget.userData['address']);
    _selectedBloodGroup = widget.userData['bloodGroup'];
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) setState(() => _newImage = File(picked.path));
  }

  Future<String?> _uploadImage() async {
    if (_newImage == null) return widget.userData['url'];
    try {
      final cloudinary = CloudinaryPublic(Application.cloud_name, Application.complaint_img);
      var response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(_newImage!.path, resourceType: CloudinaryResourceType.Image),
      );
      return response.secureUrl;
    } catch (e) {
      return null;
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isUpdating = true);
    String? imageUrl = await _uploadImage();

    try {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'bloodGroup': _selectedBloodGroup,
        'url': imageUrl,
      });

      Navigator.pop(context); // Return to profile
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile Updated successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Update failed: $e")),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)?.translate('edit_profile') ?? "Edit Profile"), backgroundColor: const Color(0xFF5B2D91), foregroundColor: Colors.white),
      body: _isUpdating
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: _newImage != null
                        ? FileImage(_newImage!) as ImageProvider
                        : (widget.userData['url'] != null ? NetworkImage(widget.userData['url']) : null),
                    child: (widget.userData['url'] == null && _newImage == null)
                        ? const Icon(Icons.person, size: 60) : null,
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        onPressed: _pickImage,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              TextFormField(controller: _nameController, decoration: InputDecoration(labelText: AppLocalizations.of(context)?.translate('full_name') ?? "Full Name", border: const OutlineInputBorder())),
              const SizedBox(height: 15),
              TextFormField(controller: _phoneController, decoration: InputDecoration(labelText: AppLocalizations.of(context)?.translate('phone_number') ?? "Phone Number", border: const OutlineInputBorder())),
              const SizedBox(height: 15),
              TextFormField(controller: _addressController, maxLines: 2, decoration: InputDecoration(labelText: AppLocalizations.of(context)?.translate('address') ?? "Address", border: const OutlineInputBorder())),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: _selectedBloodGroup,
                items: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'].map((bg) => DropdownMenuItem(value: bg, child: Text(bg))).toList(),
                onChanged: (v) => setState(() => _selectedBloodGroup = v),
                decoration: InputDecoration(labelText: AppLocalizations.of(context)?.translate('blood_group') ?? "Blood Group", border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _updateProfile,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B2D91), foregroundColor: Colors.white),
                  child: Text(AppLocalizations.of(context)?.translate('save') ?? "Save Changes"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}