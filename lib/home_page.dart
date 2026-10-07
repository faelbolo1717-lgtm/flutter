import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_page.dart';
import 'room_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _searchQuery = '';
  String _userName = 'Tamu'; // Nama default jika data belum dimuat
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // FUNGSI MENGAMBIL NAMA USER SECARA OTOMATIS
  Future<void> _loadUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final data = await _supabase
            .from('profiles')
            .select('full_name')
            .eq('id', user.id)
            .single();
        
        if (mounted) {
          setState(() {
            _userName = data['full_name'] ?? 'User';
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }
  }

  // 1. Fungsi Mengambil Data Kamar
  Future<List<Map<String, dynamic>>> _fetchRooms() async {
    final data = await _supabase
        .from('rooms')
        .select('*, room_categories(*)')
        .order('room_number');
    return List<Map<String, dynamic>>.from(data);
  }

  // 2. Fungsi Proses Booking
  Future<void> _bookRoom(Map<String, dynamic> room) async {
    final userId = _supabase.auth.currentUser?.id;
    final num pricePerNight = room['room_categories']['price_per_night'] ?? 0;

    final DateTimeRange? pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      saveText: 'KONFIRMASI',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.green),
          ),
          child: child!,
        );
      },
    );

    if (pickedRange == null) return;

    final int totalNights = pickedRange.duration.inDays == 0 ? 1 : pickedRange.duration.inDays;
    final num totalPrice = totalNights * pricePerNight;

    try {
      await _supabase.from('bookings').insert({
        'user_id': userId,
        'room_id': room['id'],
        'check_in': pickedRange.start.toIso8601String(),
        'check_out': pickedRange.end.toIso8601String(),
        'total_price': totalPrice,
      });

      await _supabase
          .from('rooms')
          .update({'is_available': false})
          .eq('id', room['id']);

      if (mounted) {
        _showSuccessDialog(room['room_number'], totalPrice, totalNights);
        setState(() {}); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSuccessDialog(String roomNum, num price, int nights) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Booking Berhasil!"),
        content: Text("Kamar $roomNum telah dipesan untuk $nights malam.\nTotal: Rp $price"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("EcoStay Explorer", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage())).then((_) => _loadUserProfile()),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _supabase.auth.signOut();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER SAMBUTAN DINAMIS
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 20, right: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Halo, $_userName!", 
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green[800]),
                ),
                const Text("Mau menginap di mana hari ini?", style: TextStyle(fontSize: 16, color: Colors.black54)),
              ],
            ),
          ),

          // BAR PENCARIAN
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: "Cari nomor atau tipe...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // DAFTAR KAMAR
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchRooms(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Terjadi kesalahan: ${snapshot.error}"));
                }

                final rooms = snapshot.data!.where((room) {
                  final roomNum = room['room_number'].toString().toLowerCase();
                  final type = room['room_type'].toString().toLowerCase();
                  final catName = room['room_categories']['name'].toString().toLowerCase();
                  return roomNum.contains(_searchQuery.toLowerCase()) ||
                         type.contains(_searchQuery.toLowerCase()) ||
                         catName.contains(_searchQuery.toLowerCase());
                }).toList();

                if (rooms.isEmpty) {
                  return const Center(child: Text("Kamar tidak ditemukan."));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    final category = room['room_categories'];
                    final bool isAvail = room['is_available'] ?? false;

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RoomDetailPage(room: room),
                          ),
                        ).then((_) => setState(() {})); 
                      },
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  room['image_url'] ?? 'https://via.placeholder.com/150',
                                  width: 90, height: 90, fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 90, height: 90, color: Colors.grey[200],
                                    child: const Icon(Icons.broken_image, color: Colors.grey),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Kamar ${room['room_number']}",
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      "${room['room_type']} - ${category['name']}",
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Rp ${category['price_per_night']} / malam",
                                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: isAvail ? () => _bookRoom(room) : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isAvail ? Colors.green : Colors.grey[400],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text(isAvail ? "Pesan" : "Penuh"),
                              ),
                            ],
                          ),
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