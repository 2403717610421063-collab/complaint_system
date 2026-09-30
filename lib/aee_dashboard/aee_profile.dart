import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AeeProfilePage extends StatefulWidget {
	const AeeProfilePage({super.key});

	@override
	State<AeeProfilePage> createState() => _AeeProfilePageState();
}

class _AeeProfilePageState extends State<AeeProfilePage> {
	static const _purple = Color(0xFF7B1FA2);
	static const _purpleLight = Color(0xFFF3E8FF);
	static const _bg = Color(0xFFF4F3F9);

	final TextEditingController _nameController = TextEditingController();
	bool _isEditingName = false;
	bool _saving = false;

	@override
	void dispose() {
		_nameController.dispose();
		super.dispose();
	}

	Future<void> _saveName(String uid) async {
		if (_saving) return;
		final name = _nameController.text.trim();
		if (name.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Name cannot be empty')),
			);
			return;
		}

		setState(() => _saving = true);
		try {
			await FirebaseFirestore.instance.collection('Users').doc(uid).update({
				'name': name,
			});

			if (!mounted) return;
			setState(() => _isEditingName = false);
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Name updated successfully')),
			);
		} catch (e) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('Failed to update name: $e')),
			);
		} finally {
			if (mounted) setState(() => _saving = false);
		}
	}

	@override
	Widget build(BuildContext context) {
		final user = FirebaseAuth.instance.currentUser;
		if (user == null) {
			return const Scaffold(body: Center(child: Text('No user found')));
		}

		return Scaffold(
			backgroundColor: _bg,
			appBar: AppBar(
				backgroundColor: _purple,
				automaticallyImplyLeading: false,
				title: Text(
					'AEE Profile',
					style: GoogleFonts.spaceGrotesk(
						color: Colors.white,
						fontWeight: FontWeight.w700,
					),
				),
			),
			body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
				stream: FirebaseFirestore.instance.collection('Users').doc(user.uid).snapshots(),
				builder: (context, snapshot) {
					if (!snapshot.hasData) {
						return const Center(child: CircularProgressIndicator());
					}

					final data = snapshot.data!.data() ?? <String, dynamic>{};
					final currentName = (data['name'] ?? '').toString();
					final email = (data['email'] ?? '').toString();
					final role = (data['officialRole'] ?? '').toString();
					final phone = (data['phone'] ?? '').toString();

					if (!_isEditingName && _nameController.text != currentName) {
						_nameController.text = currentName;
					}

					return SingleChildScrollView(
						padding: const EdgeInsets.all(20),
						child: Column(
							children: [
								Container(
									width: double.infinity,
									padding: const EdgeInsets.all(20),
									decoration: BoxDecoration(
										color: Colors.white,
										borderRadius: BorderRadius.circular(20),
										boxShadow: [
											BoxShadow(
												color: Colors.black.withOpacity(0.05),
												blurRadius: 12,
												offset: const Offset(0, 4),
											),
										],
									),
									child: Column(
										children: [
											Container(
												width: 86,
												height: 86,
												decoration: const BoxDecoration(
													color: _purpleLight,
													shape: BoxShape.circle,
												),
												child: const Icon(
													Icons.supervisor_account_rounded,
													color: _purple,
													size: 42,
												),
											),
											const SizedBox(height: 14),
											Text(
												role.isEmpty ? 'AEE' : role,
												style: GoogleFonts.spaceGrotesk(
													fontSize: 13,
													fontWeight: FontWeight.w800,
													color: _purple,
												),
											),
											const SizedBox(height: 2),
											Text(
												email,
												style: GoogleFonts.nunito(
													fontSize: 13,
													fontWeight: FontWeight.w700,
													color: const Color(0xFF64748B),
												),
											),
										],
									),
								),
								const SizedBox(height: 14),
								Container(
									width: double.infinity,
									padding: const EdgeInsets.all(18),
									decoration: BoxDecoration(
										color: Colors.white,
										borderRadius: BorderRadius.circular(20),
										boxShadow: [
											BoxShadow(
												color: Colors.black.withOpacity(0.05),
												blurRadius: 12,
												offset: const Offset(0, 4),
											),
										],
									),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Text(
												'Name (Editable)',
												style: GoogleFonts.spaceGrotesk(
													fontSize: 14,
													fontWeight: FontWeight.w800,
													color: const Color(0xFF1E0A3C),
												),
											),
											const SizedBox(height: 10),
											TextField(
												controller: _nameController,
												enabled: _isEditingName,
												decoration: InputDecoration(
													filled: true,
													fillColor: _isEditingName
															? const Color(0xFFFAF7FF)
															: const Color(0xFFF8FAFC),
													border: OutlineInputBorder(
														borderRadius: BorderRadius.circular(12),
													),
													enabledBorder: OutlineInputBorder(
														borderRadius: BorderRadius.circular(12),
														borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
													),
													focusedBorder: OutlineInputBorder(
														borderRadius: BorderRadius.circular(12),
														borderSide: const BorderSide(color: _purple, width: 1.4),
													),
												),
											),
											const SizedBox(height: 12),
											Row(
												children: [
													ElevatedButton.icon(
														onPressed: _saving
																? null
																: () => setState(() => _isEditingName = !_isEditingName),
														icon: Icon(_isEditingName ? Icons.close : Icons.edit, size: 16),
														label: Text(_isEditingName ? 'Cancel' : 'Edit Name'),
														style: ElevatedButton.styleFrom(
															backgroundColor: _purpleLight,
															foregroundColor: _purple,
														),
													),
													const SizedBox(width: 10),
													ElevatedButton.icon(
														onPressed: (!_isEditingName || _saving)
																? null
																: () => _saveName(user.uid),
														icon: _saving
																? const SizedBox(
																		width: 14,
																		height: 14,
																		child: CircularProgressIndicator(strokeWidth: 2),
																	)
																: const Icon(Icons.save_rounded, size: 16),
														label: Text(_saving ? 'Saving...' : 'Save Name'),
														style: ElevatedButton.styleFrom(
															backgroundColor: _purple,
															foregroundColor: Colors.white,
														),
													),
												],
											),
											const SizedBox(height: 18),
											const Divider(height: 1),
											const SizedBox(height: 14),
											Text(
												'Read-only Details',
												style: GoogleFonts.spaceGrotesk(
													fontSize: 14,
													fontWeight: FontWeight.w800,
													color: const Color(0xFF1E0A3C),
												),
											),
											const SizedBox(height: 10),
											_readOnlyRow('Email', email),
											const SizedBox(height: 8),
											_readOnlyRow('Phone', phone.isEmpty ? 'N/A' : phone),
											const SizedBox(height: 8),
											_readOnlyRow('Role', role.isEmpty ? 'AEE' : role),
										],
									),
								),
							],
						),
					);
				},
			),
		);
	}

	Widget _readOnlyRow(String label, String value) {
		return Row(
			children: [
				SizedBox(
					width: 86,
					child: Text(
						label,
						style: GoogleFonts.nunito(
							fontSize: 12,
							fontWeight: FontWeight.w700,
							color: const Color(0xFF64748B),
						),
					),
				),
				Expanded(
					child: Text(
						value,
						style: GoogleFonts.spaceGrotesk(
							fontSize: 13,
							fontWeight: FontWeight.w700,
							color: const Color(0xFF1E0A3C),
						),
					),
				),
			],
		);
	}
}
