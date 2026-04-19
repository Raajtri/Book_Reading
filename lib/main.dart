import 'package:book/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lottie/lottie.dart';
import 'splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('reader');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final box = Hive.box('reader');
  List books = [];

  @override
  void initState() {
    super.initState();
    loadBooks(); // ✅ FIXED
  }

  void loadBooks() {
    final data = box.get('books', defaultValue: []);
    setState(() {
      books = List.from(data);
    });
  }

  void addBook(Map book) {
    books.add(book);
    box.put('books', books);
    loadBooks();
  }

  void removeBook(int index) {
    books.removeAt(index);
    box.put('books', books);
    loadBooks();
  }

  Future pickPDF() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      String path = result.files.single.path!;
      String name = result.files.single.name;

      final box = Hive.box('reader');
      List books = List.from(box.get('books', defaultValue: []));

      String normalizedPath = path.toLowerCase().trim();

      bool exists = books.any((b) {
        String existingPath = (b['path'] as String).toLowerCase().trim();
        return existingPath == normalizedPath || b['name'] == name;
      });

      if (exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Book already added")),
        );
        return;
      }

      addBook({
        "path": path,
        "name": name,
        "last_page": 0,
        "completed": false,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF191818),
      appBar: AppBar(
        title: const Text("My Library",
        style: TextStyle(
          color: Colors.white60,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 🔥 CONTINUE READING CARD
          Builder(
            builder: (context) {
              final lastPath = box.get('last_book');

              if (lastPath == null) return const SizedBox();

              final book = books.firstWhere(
                    (b) => b['path'] == lastPath,
                orElse: () => null,
              );

              if (book == null) return const SizedBox();

              return Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[850], // brighter than before
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book,
                        size: 40, color: Colors.white),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Continue Reading",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              letterSpacing: 1,
                            ),
                          ),

                          Text(
                            book['name'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          Text(
                            "Page ${book['last_page'] ?? 0}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 🔥 RESUME BUTTON
                    TextButton(
                      onPressed: () async {
                        if(books.isEmpty)return;

                        var last= books.first;
                        await Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) =>
                                ReaderScreen(path: last['path']),
                            transitionsBuilder: (_, animation, __, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                            transitionDuration: const Duration(milliseconds: 300),
                          ),
                        );

                        loadBooks();
                      },
                      child: const Text("Resume"),
                    ),

                    // 🔥 REMOVE BUTTON
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () {
                        box.delete('last_book'); // remove continue card
                        setState(() {});
                      },
                    )
                  ],
                ),
              );
            },
          ),

          // 🔥 GRID
          Expanded(
            child: books.isEmpty
                ? const Center(child: Text("No books added"))
                : GridView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: books.length,
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
              ),
              itemBuilder: (context, index) {
                final book = books[index];
                int last = book['last_page'] ?? 0;
                int total = book['total_pages'] ?? 1;

                double progress = total > 0 ? last / total : 0;
                int percent = (progress * 100).toInt();

                return GestureDetector(
                  onTap: () async {
                    Hive.box('reader').put('last_book', book['path']);

                    await Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) =>
                            ReaderScreen(path: book['path']),
                        transitionsBuilder: (_, animation, __, child) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                        transitionDuration: const Duration(milliseconds: 300),
                      ),
                    );

                    loadBooks();
                  },

                  onLongPress: () {
                    removeBook(index);
                  },

                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,

                    child: Card(
                      color: const Color(0xFF1E1E1E),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [

                            Container(
                              height: 80,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.menu_book,
                                size: 60,
                                color: Colors.white70,
                              ),
                            ),

                            Text(
                              book['name'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            Text(
                              "Page ${book['last_page'] ?? 0}",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),

                            // 🔥 PROGRESS TEXT
                            Text(
                              "$percent% completed",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),

                            const SizedBox(height: 4),

                            // 🔥 PROGRESS BAR
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: Colors.grey.shade800,
                                valueColor: const AlwaysStoppedAnimation(Colors.green),
                              ),
                            ),

                            const SizedBox(height: 4),

                            if (book['completed']==true)
                              const Text(
                                "✔ Completed",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        onPressed: pickPDF,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}

class ReaderScreen extends StatefulWidget {
  final String path;

  const ReaderScreen({super.key, required this.path});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final PdfViewerController controller = PdfViewerController();

  bool showUI = false;
  bool darkMode = false; // ✅ default light
  int currentPage = 1;
  bool isLoading = true;
  String? lastSavedText; // ✅ prevents duplicate highlight

  Future<void> saveAnnotation({
    required String text,
    required int page,
  }) async {
    final box = Hive.box('reader');

    List annotations =
    List.from(box.get('annotations', defaultValue: []));

    // ✅ prevent duplicate
    bool exists = annotations.any((a) =>
    a['text'] == text &&
        a['page'] == page &&
        a['path'] == widget.path);

    if (exists) return;

    annotations.add({
      "path": widget.path,
      "page": page,
      "text": text,
    });

    box.put('annotations', annotations);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Highlight saved")),
    );
  }

  @override
  void initState() {
    super.initState();

    final box = Hive.box('reader');
    List books = List.from(box.get('books', defaultValue: []));

    for (var book in books) {
      if (book['path'] == widget.path) {
        int? page = book['last_page'];

        if (page != null && page > 0) {
          Future.delayed(const Duration(milliseconds: 500), () {
            controller.jumpToPage(page);
          });
        }
      }
    }
  }

  void showJumpToPageDialog() {
    final TextEditingController input = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            "Go to page",
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: input,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "Enter page number",
              hintStyle: TextStyle(color: Colors.grey),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                final page = int.tryParse(input.text);

                if (page != null && page > 0) {
                  controller.jumpToPage(page);
                }

                Navigator.pop(context);
              },
              child: const Text("Go"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalPages=0;
    Widget pdfViewer = SfPdfViewer.file(

      File(widget.path),
      controller: controller,

      pageLayoutMode: PdfPageLayoutMode.single,
      scrollDirection: PdfScrollDirection.horizontal,
      canShowTextSelectionMenu: true,

      // ✅ FIXED highlight logic
      onTextSelectionChanged: (details) async {
        final text = details.selectedText;

        if (text != null &&
            text.length>3 &&
            text != lastSavedText) {

          lastSavedText = text;

          await saveAnnotation(
            text: text,
            page: currentPage,
          );
        }
      },

      onPageChanged: (details) {
        setState(() {
          currentPage = details.newPageNumber;
        });

        final box = Hive.box('reader');
        List books =
        List.from(box.get('books', defaultValue: []));

        for (int i = 0; i < books.length; i++) {
          if (books[i]['path'] == widget.path) {
            books[i]['last_page'] = currentPage;

            //mark complete
            if (totalPages>0 && currentPage >= totalPages){
              books[i]['completed']=true;
            }
            else{
              books[i]['completed'] = false;
            }
          }
        }

        box.put('books', books);
      },

      onDocumentLoaded: (details){
        totalPages=details.document.pages.count;// get total pages
        final box = Hive.box('reader');
        List books = List.from(box.get('books', defaultValue: []));

        for (int i = 0; i < books.length; i++) {
          if (books[i]['path'] == widget.path) {
            books[i]['total_pages'] = totalPages; // save total
          }
        }

        box.put('books', books);
        setState(() {
          isLoading=false;
        });
      },

      onDocumentLoadFailed: (details){
        setState(() {
          isLoading=false;
        });
      },
    );

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [

          // 📄 PDF VIEW (single viewer)
          darkMode
              ? ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              -1, 0, 0, 0, 255,
              0,-1, 0, 0, 255,
              0, 0,-1, 0, 255,
              0, 0, 0, 1,   0,
            ]),
            child: pdfViewer,
          )
              : pdfViewer,

          if (isLoading)
            Container(
              color: const Color(0xFF121212),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    Lottie.asset(
                      "assets/loading.json",
                      width: 150,
                    ),

                    const SizedBox(height: 20),

                                      ],
                ),
              ),
            ),

          // 👆 tap layer
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                setState(() {
                  showUI = !showUI;
                });
              },
            ),
          ),

          AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: showUI ? 1 : 0,
            child: IgnorePointer(
              ignoring: !showUI,
              child: Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [

                          // 🔙 back
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),

                          const Text(
                            "Reading",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          IconButton(
                            icon: const Icon(Icons.search,
                                color: Colors.white),
                            onPressed: showJumpToPageDialog,
                          ),

                          // 🌗 dark toggle
                          IconButton(
                            icon: Icon(
                              darkMode
                                  ? Icons.dark_mode
                                  : Icons.light_mode,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                darkMode = !darkMode;
                              });
                            },
                          ),

                          // 🔖 highlights
                          IconButton(
                            icon: const Icon(Icons.bookmark,
                                color: Colors.white),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                  const AnnotationScreen(),
                                  settings: RouteSettings(
                                      arguments: widget.path),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 🔽 page indicator
          if (showUI)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Page $currentPage",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AnnotationScreen extends StatefulWidget {
  const AnnotationScreen({super.key});

  @override
  State<AnnotationScreen> createState() => _AnnotationScreenState();
}

class _AnnotationScreenState extends State<AnnotationScreen>{
  @override
  Widget build(BuildContext context) {
    final box = Hive.box('reader');
    final String currentPath =
    ModalRoute.of(context)!.settings.arguments as String;

    List all =
    List.from(box.get('annotations', defaultValue: []));

    List annotations =
    all.where((a) => a['path'] == currentPath).toList();
    return Scaffold(
      appBar: AppBar(title: const Text("Highlights")),
      body: annotations.isEmpty
          ? const Center(child: Text("No highlights yet"))
          : ListView.builder(
        itemCount: annotations.length,
        itemBuilder: (context, index) {
          final a = annotations[index];

          return Card(
            color: const Color(0xFF1E1E1E),
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              title: Text(
                a['text'],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                "Page ${a['page']}",
                style: const TextStyle(color: Colors.grey),
              ),

              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() {
                    all.remove(a);
                    box.put('annotations', all);
                  });
                },
              ),
            ),
          );
        },
      ),
    );
  }
}