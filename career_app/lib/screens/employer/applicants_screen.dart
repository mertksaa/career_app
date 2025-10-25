// lib/screens/employer/applicants_screen.dart
// TÜM HATALARI DÜZELTİLMİŞ VERSİYON
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/applicant_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import './cv_viewer_screen.dart';

class ApplicantsScreen extends StatefulWidget {
  final int jobId;
  final String jobTitle;

  const ApplicantsScreen({
    Key? key,
    required this.jobId,
    required this.jobTitle,
  }) : super(key: key);

  @override
  State<ApplicantsScreen> createState() => _ApplicantsScreenState();
}

class _ApplicantsScreenState extends State<ApplicantsScreen> {
  late Future<List<Applicant>> _applicantsFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _applicantsFuture = _fetchApplicants();
  }

  Future<List<Applicant>> _fetchApplicants() async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) {
      throw Exception('Giriş yapılmamış veya token geçersiz.');
    }
    try {
      return await _apiService.getApplicants(token, widget.jobId);
    } catch (e) {
      print("Error fetching applicants: $e");
      throw Exception('Başvuranlar yüklenemedi: $e');
    }
  }

  // <<< DÜZELTME 1: _refreshApplicants (Dönüş tipi hatası) >>>
  Future<void> _refreshApplicants() async {
    // setState'i çağır ve yeni future'ı ata
    setState(() {
      _applicantsFuture = _fetchApplicants();
    });
    // RefreshIndicator'ın beklemesi için future'ı 'await' et.
    // 'return' etme, çünkü fonksiyon 'void' döndürmeli.
    await _applicantsFuture;
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return 'Bilinmiyor';
    try {
      // 1. Adım: Tarih metnini parse et
      final dateTime = DateTime.parse(dateString);

      // 2. Adım: Parçaları manuel olarak al ve formatla
      // Başına '0' eklemek için padLeft(2, '0') kullan
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year;
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');

      // 3. Adım: "GG.AA.YYYY SS:DD" formatında birleştir
      return '$day.$month.$year $hour:$minute';
    } catch (e) {
      // Eğer parse işlemi yine de başarısız olursa (beklenmedik format)
      // En azından 'T' harfini ve saniyeleri atmayı dene
      try {
        List<String> parts = dateString.split('T');
        String datePart = parts[0]
            .split('-')
            .reversed
            .join('.'); // YYYY-AA-GG -> GG.AA.YYYY
        String timePart = parts[1].substring(0, 5); // SS:DD
        return '$datePart $timePart';
      } catch (e2) {
        // Bu da başarısız olursa, çirkin de olsa orijinal veriyi göster
        return dateString;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.jobTitle} - Başvuranlar')),
      body: RefreshIndicator(
        onRefresh: _refreshApplicants,
        child: FutureBuilder<List<Applicant>>(
          future: _applicantsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 60,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Başvuranlar yüklenirken bir hata oluştu.\n(${snapshot.error})',
                        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tekrar Dene'),
                        onPressed: _refreshApplicants,
                      ),
                    ],
                  ),
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 60,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Henüz başvuran yok.',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Listeyi yenilemek için aşağı çekin.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }

            final applicants = snapshot.data!;
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: applicants.length,
              itemBuilder: (context, index) {
                final applicant = applicants[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: ListTile(
                    // applicant.hasCv artık modelden (Düzeltme 1) geliyor
                    leading: CircleAvatar(
                      child: Icon(
                        applicant.hasCv
                            ? Icons.person
                            : Icons.person_off_outlined,
                      ),
                      backgroundColor: applicant.hasCv
                          ? Theme.of(context).primaryColorLight
                          : Colors.grey[300],
                      foregroundColor: applicant.hasCv
                          ? Theme.of(context).primaryColor
                          : Colors.grey[600],
                    ),
                    title: Text(applicant.email),
                    // applicant.applicationDate artık modelden (Düzeltme 1) geliyor
                    subtitle: Text(
                      'Başvuru: ${_formatDate(applicant.applicationDate)}',
                    ),
                    trailing: applicant.hasCv
                        ? Tooltip(
                            message: '${applicant.email} CV\'sini Görüntüle',
                            child: ElevatedButton.icon(
                              icon: const Icon(
                                Icons.picture_as_pdf_outlined,
                                size: 18,
                              ),
                              label: const Text('CV'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    // <<< DÜZELTME 2: CvViewerScreen Constructor (Parametre hatası) >>>
                                    // Hata mesajına göre 'userId' ve 'userEmail' gerekli.
                                    builder: (context) => CvViewerScreen(
                                      userId: applicant
                                          .userId, // 'applicantUserId' DEĞİL
                                      userEmail: applicant
                                          .email, // 'applicantEmail' DEĞİL
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        : Text(
                            'CV Yok',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
