import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RoomDetailPage extends StatefulWidget {
  final Map<String, dynamic> room;
  const RoomDetailPage({super.key, required this.room});

  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  final _supabase = Supabase.instance.client;

  // Query untuk mengambil ulasan dari tabel reviews join dengan profiles
  Future<List<Map<String, dynamic>>> _fetchReviews() async {
    final data = await _supabase
        .from('reviews')
        .select('*, profiles(full_name)')
        .eq('room_id', widget.room['id'])
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.room['room_categories'];
    final bool isAvail = widget.room['is_available'] ?? false;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header dengan Gambar Besar yang bisa discroll (SliverAppBar)
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text("Kamar ${widget.room['room_number']}"),
              background: Image.network(
                widget.room['image_url'] ?? 'https://via.placeholder.com/600x400',
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Informasi Harga & Tipe
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(category['name'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            Text(widget.room['room_type'], style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                          ],
                        ),
                        Text(
                          "Rp ${category['price_per_night']}\n/malam",
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Fasilitas (Statis untuk mempercantik UI)
                    const Text("Fasilitas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _FeatureIcon(icon: Icons.wifi, label: "WiFi"),
                        _FeatureIcon(icon: Icons.ac_unit, label: "AC"),
                        _FeatureIcon(icon: Icons.tv, label: "TV"),
                        _FeatureIcon(icon: Icons.hot_tub, label: "Water Heater"),
                      ],
                    ),
                    const Divider(height: 40),

                    // Bagian Ulasan Tamu
                    const Text("Ulasan Tamu", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _fetchReviews(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Text("Belum ada ulasan untuk kamar ini.", style: TextStyle(fontStyle: FontStyle.italic)),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            final rev = snapshot.data![index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: const CircleAvatar(child: Icon(Icons.person)),
                                title: Text(rev['profiles']['full_name'] ?? "Tamu EcoStay"),
                                subtitle: Text(rev['comment'] ?? ""),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 18),
                                    Text(rev['rating'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 100), // Ruang agar tidak tertutup tombol bawah
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
      
      // Tombol Pesan di Posisi Bawah Tetap (Floating)
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
        child: ElevatedButton(
          onPressed: isAvail ? () {
            // Logika pesan bisa ditaruh di sini atau panggil fungsi dari HomePage
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Silakan pesan melalui halaman utama")));
          } : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: isAvail ? Colors.green : Colors.grey,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(isAvail ? "PESAN SEKARANG" : "KAMAR PENUH", style: const TextStyle(fontSize: 16, color: Colors.white)),
        ),
      ),
    );
  }
}

// Widget Kecil untuk Icon Fasilitas
class _FeatureIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureIcon({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.green[700], size: 28),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}