import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _getProfile();
  }

  Future<void> _getProfile() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final data = await _supabase.from('profiles').select().eq('id', userId).single();
      _nameController.text = data['full_name'] ?? '';
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // FUNGSI MENGAMBIL DATA BOOKING DARI DATABASE
  Future<List<Map<String, dynamic>>> _fetchMyBookings() async {
    final userId = _supabase.auth.currentUser!.id;
    final data = await _supabase
        .from('bookings')
        .select('*, rooms(room_number, room_type)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      await _supabase.from('profiles').update({
        'full_name': _nameController.text,
      }).eq('id', userId);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil diperbarui!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profil & Riwayat"), backgroundColor: Colors.green[700], foregroundColor: Colors.white),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // BAGIAN ATAS: EDIT PROFIL
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: "Nama Lengkap", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _updateProfile,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 45)),
                      child: const Text("Simpan Nama", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
              const Divider(thickness: 10, color: Color(0xFFEEEEEE)),
              
              // BAGIAN BAWAH: DAFTAR RIWAYAT
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Riwayat Pesanan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchMyBookings(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text("Bel_um ada pesanan."));
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final booking = snapshot.data![index];
                        final room = booking['rooms'];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: const Icon(Icons.hotel, color: Colors.green),
                            title: Text("Kamar ${room['room_number']} (${room['room_type']})"),
                            subtitle: Text("Check-in: ${booking['check_in'].toString().substring(0,10)}"),
                            trailing: Text(
                              "Rp ${booking['total_price']}",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }
}