import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';

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
      home: HomeScreen(),
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

      addBook({
        "path": path,
        "name": name,
        "last_page": 0,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("My Library"),
        backgroundColor: Colors.black,
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
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ReaderScreen(path: book['path']),
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

                return GestureDetector(
                  onTap: () async {
                    Hive.box('reader')
                        .put('last_book', book['path']);

                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ReaderScreen(path: book['path']),
                      ),
                    );

                    loadBooks();
                  },
                  onLongPress: () {
                    removeBook(index);
                  },
                    child: Card(
                      color: Colors.grey[850], // slightly brighter
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Icon(Icons.book,
                                size: 60, color: Colors.white),

                            Text(
                              book['name'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
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
                    )
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: pickPDF,
        child: const Icon(Icons.add),
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
  bool darkMode= true;
  int currentPage = 1;
  Future<void> saveAnnotation({
    required String text,
    required int page,
  }) async {
    final box = Hive.box('reader');

    List annotations =
    List.from(box.get('annotations', defaultValue: []));

    annotations.add({
      "path": widget.path,
      "page": page,
      "text": text,
      "time": DateTime.now().toString(),
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          // 📄 PDF VIEW
          darkMode
              ? ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              -1, 0, 0, 0, 255,
              0,-1, 0, 0, 255,
              0, 0,-1, 0, 255,
              0, 0, 0, 1,   0,
            ]),
            child: SfPdfViewer.file(
              File(widget.path),
              controller: controller,
              canShowTextSelectionMenu: true,

              onTextSelectionChanged: (details) async {
                if (details.selectedText != null) {
                  await saveAnnotation(
                    text: details.selectedText!,
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
                  }
                }

                box.put('books', books);
              },
            ),
          )
              : SfPdfViewer.file(
            File(widget.path),
            controller: controller,
            canShowTextSelectionMenu: true,

            onTextSelectionChanged: (details) async {
              if (details.selectedText != null) {
                await saveAnnotation(
                  text: details.selectedText!,
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
                }
              }

              box.put('books', books);
            },
          ),

          // 🔥 TAP DETECTOR LAYER (IMPORTANT)
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

          // 🔝 TOP BAR
          if (showUI)
            Positioned(
              top: 40,
              left: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(10),
                ),

                child: Row(
                  mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
                  children: [
                    // 🔙 BACK BUTTON
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),

                    // 📖 TITLE
                    const Text(
                      "Reading",
                      style: TextStyle(color: Colors.white),
                    ),

                    IconButton(
                      icon: Icon(
                        darkMode ? Icons.dark_mode : Icons.light_mode,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          darkMode = !darkMode;
                        });
                      },
                    ),

                    // 🔖 HIGHLIGHT LIST BUTTON
                    IconButton(
                      icon: const Icon(Icons.bookmark, color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AnnotationScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

          // 🔽 PAGE INDICATOR
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

class AnnotationScreen extends StatelessWidget {
  const AnnotationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('reader');
    List annotations =
    List.from(box.get('annotations', defaultValue: []));

    return Scaffold(
      appBar: AppBar(title: const Text("Highlights")),
      body: annotations.isEmpty
          ? const Center(child: Text("No highlights yet"))
          : ListView.builder(
        itemCount: annotations.length,
        itemBuilder: (context, index) {
          final a = annotations[index];

          return ListTile(
            title: Text(a['text']),
            subtitle: Text("Page ${a['page']}"),
          );
        },
      ),
    );
  }
}