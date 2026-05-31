import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

import 'package:http/http.dart' as http; 
import 'dart:convert'; 
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'package:flutter/services.dart' show rootBundle;

import 'api_config.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Congressional App',
      theme: ThemeData(
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: Colors.lightGreen,
          onPrimary: Colors.white,
          secondary: Colors.lightGreen, 
          onSecondary: Colors.white,
          surface: const Color(0xFFFFFDE7),
          onSurface: Colors.black,
          error: Colors.red,
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFFFFDE7),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _isLoggedIn = false; 
  String? _username;
  bool _isLoading = true; 

  @override
  void initState() {
    super.initState();
    _checkLoginStatusOnStartup();
    
    Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isLoggedIn) {
        _refreshTokenValidity();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _checkLoginStatusOnStartup() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final username = prefs.getString('username');

    debugPrint('Startup check - token: ${token != null ? 'exists' : 'null'}, username: $username');

    if (token != null && username != null) {
      final isValid = await _verifyToken(token);
      debugPrint('Token validation result: $isValid');
      if (isValid) {
        setState(() {
          _isLoggedIn = true;
          _username = username;
          _isLoading = false;
        });
        debugPrint('User logged in: $_username');
      } else {
        await _clearStoredAuth();
        setState(() {
          _isLoggedIn = false;
          _username = null;
          _isLoading = false;
        });
        debugPrint('Token invalid, cleared auth data');
      }
    } else {
      setState(() {
        _isLoggedIn = false;
        _username = null;
        _isLoading = false;
      });
      debugPrint('No stored auth data found');
    }
  }

  Future<void> _refreshTokenValidity() async {
    if (_isLoggedIn) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token != null) {
        final isValid = await _verifyToken(token);
        if (!isValid) {
          await _clearStoredAuth();
          setState(() {
            _isLoggedIn = false;
            _username = null;
          });
          
          if (mounted) {
            _showSessionExpiredDialog();
          }
        }
      }
    }
  }

  void _showSessionExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Session Expired'),
          content: const Text('Your login session has expired. Please log in again to continue.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _verifyToken(String token) async {
    try {
      debugPrint('Verifying token: ${token.substring(0, 20)}...');
      final url = apiUri('/verify-token');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token,
        },
      );
      debugPrint('Token verification response status: ${response.statusCode}');
      debugPrint('Token verification response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isValid = data['valid'] == true;
        debugPrint('Token validation result: $isValid');
        return isValid;
      }
      return false;
    } catch (e) {
      debugPrint('Error verifying token: $e');
      return false;
    }
  }

  Future<void> _clearStoredAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('username');
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    if (_isLoggedIn && index == 2) { 
      _refreshTokenValidity();
    }
  }

  void _updateLoginStatus(bool isLoggedIn, String? username) {
    debugPrint('_updateLoginStatus called: isLoggedIn=$isLoggedIn, username=$username');
    setState(() {
      _isLoggedIn = isLoggedIn;
      _username = username;
    });
  }

  void _logout() async {
    await _clearStoredAuth();
    setState(() {
      _isLoggedIn = false;
      _username = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final List<Widget> pages = [
      Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('Home Page', style: TextStyle(fontSize: 24)),
              const SizedBox(height: 24),
              // Information Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.info, size: 24),
                  label: const Text(
                    'Information & Quiz',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    minimumSize: const Size(double.infinity, 80),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const InformationPage()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Scoreboard Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward_ios, size: 24),
                  label: const Text(
                    'View Global\nScoreboard',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    minimumSize: const Size(double.infinity, 80),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const ScoreboardPage()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Map Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.map, size: 24),
                  label: const Text(
                    'View Map',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    minimumSize: const Size(double.infinity, 80),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const MapsPage()),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      const TakePhotoPage(),
      ProfilePage(
        isLoggedIn: _isLoggedIn,
        username: _username,
        onUpdateLogin: _updateLoginStatus,
        onLogout: _logout,
      ),
    ];
    
    return Scaffold(
      appBar: (_isLoggedIn && _selectedIndex == 0) ? AppBar(
        title: Text('Welcome, ${_username ?? 'User'}!'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ) : null,
      body: pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.2),
              spreadRadius: 5,
              blurRadius: 10,
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.pinkAccent,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt),
              label: 'Take Photo',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class MapsPage extends StatefulWidget {
  const MapsPage({super.key});

  @override
  State<MapsPage> createState() => _MapsPageState();
}

class _MapsPageState extends State<MapsPage> {
  GoogleMapController? mapController; 
    @override
    void initState() {
      super.initState();
      _requestLocationPermission();
    }
    bool _locationPermissionGranted = false;

    Future<void> _requestLocationPermission() async {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        if (mounted) {
          setState(() {
            _locationPermissionGranted = true;
          });
        }
      }
    }

    final CameraPosition _initialPosition = const CameraPosition(
      target: LatLng(37.7749, -122.4194), // SF
      zoom: 12,
    );

    void _onMapCreated(GoogleMapController controller) {
      mapController = controller;
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Google Maps'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: GoogleMap( 
          mapType: MapType.normal,
          initialCameraPosition: _initialPosition,
          onMapCreated: _onMapCreated, 
          myLocationEnabled: true,
          compassEnabled: true,
        ),
      );
    }
    
    @override
    void dispose() {
      mapController?.dispose();
      super.dispose();
    }
}

class InformationPage extends StatefulWidget {
  const InformationPage({super.key});

  @override
  State<InformationPage> createState() => _InformationPageState();
}

class _InformationPageState extends State<InformationPage> {
  String _informationText = '';
  bool _isLoading = true;
  
  String _selectedTopic = '';
  List<Map<String, dynamic>> _quizQuestions = []; 
  
  int _currentQuestionIndex = 0;
  int _score = 0;
  String? _selectedAnswer;
  bool _quizCompleted = false;
  bool _isLoggedIn = false;
  String? _username;
  
  bool _showFeedback = false; 
  String _feedbackMessage = '';
  Color _feedbackColor = Colors.transparent;
  
  late List<String> _quizTopics;

  final Map<String, List<Map<String, dynamic>>> fullQuizBank = {
    "Environmental Impact": [
      {
        "question": "What is the primary environmental benefit of composting organic waste instead of sending it to a landfill?",
        "options": ["Saves money on landfill fees", "Creates natural fertilizer and reduces Methane production", "Reduces the amount of glass waste", "Increases the speed of decomposition"],
        "correct": 1,
        "explanation": "Composting is an aerobic process that produces nutrient-rich soil amendment and avoids the powerful greenhouse gas, Methane, which is produced in landfills."
      },
      {
        "question": "Which negative environmental outcome is primarily caused by recyclable materials being dumped in a landfill?",
        "options": ["The recyclables instantly catch fire.", "It forces the consumption of new raw materials and energy for manufacturing.", "It makes the garbage heavier for collection trucks.", "It prevents water from soaking into the ground."],
        "correct": 1,
        "explanation": "The key loss is the resource itself, forcing more energy-intensive extraction and processing of new raw materials (mining, drilling, logging)."
      },
      {
        "question": "If organic waste is placed in a landfill, the anaerobic decomposition process primarily generates which potent greenhouse gas?",
        "options": ["Carbon Dioxide", "Oxygen", "Methane", "Nitrogen"],
        "correct": 2,
        "explanation": "When buried in an oxygen-free (anaerobic) landfill, organic waste produces Methane, which is a very powerful greenhouse gas."
      },
      {
        "question": "What is the main role of a modern sanitary landfill in the waste management hierarchy?",
        "options": ["To break down all waste into soil and water.", "To recycle glass and metal scraps.", "To perpetually store waste that cannot be recycled, composted, or safely recovered for energy.", "To serve as a temporary holding area before incineration."],
        "correct": 2,
        "explanation": "Landfills are the final disposal method for residual waste (unusable items, contaminants, certain ashes) with no viable alternative."
      },
      {
        "question": "Which action has the greatest positive impact on reducing a household's carbon footprint from waste?",
        "options": ["Collecting all junk mail separately.", "Rinsing all plastic containers very thoroughly.", "Significantly reducing overall consumption (the 'reduce' part of 'reduce, reuse, recycle').", "Using only paper bags for groceries instead of plastic bags."],
        "correct": 2,
        "explanation": "Source reduction (reducing consumption) is the most impactful step, as it avoids resource extraction, manufacturing, transport, and disposal entirely."
      }
    ],
    "Processing of Trash": [
      {
        "question": "In a Materials Recovery Facility (MRF), how is aluminum typically separated from other materials like plastic and paper?",
        "options": ["By powerful magnets.", "By floating the aluminum on water.", "By optical scanners identifying the metal's color.", "By generating an **eddy current** to repel the non-ferrous metal."],
        "correct": 3,
        "explanation": "Aluminum is non-ferrous, so MRFs use a high-speed rotating magnetic field to create an eddy current in the aluminum, causing it to jump off the conveyor belt."
      },
      {
        "question": "What is the primary function of the **curing stage** in commercial composting?",
        "options": ["To quickly heat the compost to kill pathogens and weed seeds.", "To stabilize the material and mature the compost into humus.", "To separate the large debris like sticks and rocks.", "To turn the compost pile for aeration."],
        "correct": 1,
        "explanation": "The curing phase is a slow, low-temperature process that allows microorganisms to further stabilize and mature the compost into humus."
      },
      {
        "question": "A key challenge in recycling plastics is that different plastic resins (e.g., PET #1, HDPE #2) cannot be mixed during the melting process.",
        "options": ["True", "False"],
        "correct": 0,
        "explanation": "Different plastic resins do not mix well. Melting them together results in a weak, degraded material unsuitable for new products, which is why MRFs must meticulously separate them."
      },
      {
        "question": "In the landfill process, what is **leachate**?",
        "options": ["The layer of clay used to seal the bottom of the landfill.", "A flammable gas created by decomposition.", "A toxic liquid that forms as rainwater percolates through the waste.", "The recycled plastic used to line the cover."],
        "correct": 2,
        "explanation": "Leachate is the highly contaminated liquid formed when water filters through the accumulated waste, dissolving harmful chemical compounds."
      },
      {
        "question": "Optical sorting technology in an MRF primarily uses infrared light to identify which characteristic of the material?",
        "options": ["The material's weight.", "The material's shape.", "The chemical composition (resin type) of the plastic or paper fiber.", "The material's current temperature."],
        "correct": 2,
        "explanation": "Optical scanners use near-infrared light to analyze the light spectrum reflected by the item, which reveals the item's unique chemical 'signature' or resin type."
      }
    ],
    "Material Differences": [
      {
        "question": "Why is **e-waste** (electronics) hazardous and required to be processed separately from standard recyclables?",
        "options": ["It contains valuable metals that are too complex to sort.", "It contains hazardous materials like lead, cadmium, and mercury.", "It cannot be compressed into bales.", "It is always mixed with food waste."],
        "correct": 1,
        "explanation": "E-waste requires specialized dismantling because it contains hazardous and toxic substances like lead and mercury, which must be safely removed."
      },
      {
        "question": "Which of these materials is considered the **most infinitely recyclable** without losing quality?",
        "options": ["Paper", "HDPE Plastic (#2)", "Glass", "Aluminum"],
        "correct": 2,
        "explanation": "Glass can be melted and reformed repeatedly without chemical degradation, meaning the final product is identical to the original."
      },
      {
        "question": "The primary difference in recycling **plastic** versus **metal** is that plastic must be sorted by resin type, while metal is sorted primarily by its magnetic properties.",
        "options": ["True", "False"],
        "correct": 0,
        "explanation": "This is true. Plastics must be sorted by resin type (#1 through #7). Metals are separated by magnetism (ferrous/steel) and eddy currents (non-ferrous/aluminum)."
      },
      {
        "question": "Which of the following organic items should generally **NOT** be placed in a standard backyard composting bin?",
        "options": ["Fruit and vegetable scraps", "Coffee grounds and tea bags", "Meat and dairy products", "Yard trimmings and leaves"],
        "correct": 2,
        "explanation": "Meat and dairy products should generally be excluded from backyard composting because they decompose slowly, create foul odors, and attract pests."
      },
      {
        "question": "Approximately how long does it take for a single aluminum can to fully decompose in a landfill?",
        "options": ["6 months", "10–20 years", "80–100 years", "400–500 years"],
        "correct": 2,
        "explanation": "Due to the tightly sealed, low-oxygen environment of a landfill, an aluminum can takes roughly 80 to 100 years to decompose."
      }
    ],
    "Classification/Contamination": [
      {
        "question": "What is the key problem with placing a **plastic grocery bag** in a single-stream recycling bin with paper and containers?",
        "options": ["The bag is not recyclable anywhere.", "It is too heavy for the sorting machines.", "It wraps around and jams the rotating equipment, halting the sorting process.", "It chemically degrades the paper during transport."],
        "correct": 2,
        "explanation": "Plastic bags are known as 'tanglers' because they wrap around and jam the sorting screens and conveyor belts at the Materials Recovery Facility (MRF)."
      },
      {
        "question": "A key rule for paper recycling is that it must be dry. Why?",
        "options": ["Wet paper is too heavy for the conveyor belts.", "Wet paper is harder for the optical scanners to identify.", "Water ruins the paper fibers, making the material unusable for quality recycling.", "Wet paper generates too much steam in the processing machine."],
        "correct": 2,
        "explanation": "Water permanently damages the paper fibers, significantly lowering the quality and value of the material, and can contaminate the entire batch."
      },
      {
        "question": "Which of these contaminants is known for causing serious **fire hazards** at recycling facilities?",
        "options": ["Food residue on containers.", "Clean cardboard boxes.", "Lithium-ion batteries (often found in e-waste).", "Clean aluminum foil."],
        "correct": 2,
        "explanation": "Lithium-ion batteries are highly prone to thermal runaway (catching fire) when damaged by crushing equipment, posing the single greatest fire risk in recycling facilities today."
      },
      {
        "question": "If you are unsure if an item is recyclable, the best practice is to...",
        "options": ["Place it in the recycling bin and assume the sorters will find out.", "Consult local guidelines, search online, or put it in the trash bin to prevent contamination.", "Break it into smaller pieces and put it in the recycling bin.", "Wait until the bin is full and ask the collector."],
        "correct": 1,
        "explanation": "Following the 'When in doubt, throw it out' principle is crucial to prevent contamination that can spoil an entire load of recyclables."
      },
      {
        "question": "When recycling plastic bottles, is it generally better to leave the cap on or take it off?",
        "options": ["Always take the cap off, as caps are too small to be recycled.", "Leave the cap on, as the plastic cap can be recycled with the bottle when the bottle is compressed.", "It doesn't matter, as all caps and rings are removed by machinery.", "Only put the cap back on if the bottle is completely full of liquid."],
        "correct": 1,
        "explanation": "The prevailing modern standard is to leave the cap on. When the bottle is crushed into a bale, the cap stays secured and its material is often recovered in the processing stage."
      }
    ],
    "Simple Do's & Don'ts": [
      {
        "question": "If you have used cooking oil or grease, what is the safest and most recommended disposal method?",
        "options": ["Pour it down the sink or toilet, followed by hot water.", "Pour it into the compost bin with food scraps.", "Cool it, seal it in a non-recyclable container (like a coffee can), and place it in the regular trash.", "Pour it directly into the street drain."],
        "correct": 2,
        "explanation": "Grease and oil will clog pipes if poured down the drain. The safest disposal is cooling it, sealing it in a container, and disposing of it with the general landfill trash."
      },
      {
        "question": "To save space in your bin and on the truck, what should you always do with cardboard boxes?",
        "options": ["Roll them up tightly into a log.", "Tear them into small strips of paper.", "Leave them intact so the sorters can read the label.", "**Flatten** and break them down completely."],
        "correct": 3,
        "explanation": "Flattening cardboard boxes saves significant space in your bin, the collection truck, and at the sorting facility, greatly increasing efficiency."
      },
      {
        "question": "Why is it important to never put sharp objects (like broken glass or syringes) loosely into the trash or recycling bin?",
        "options": ["They cause equipment failure in the recycling machinery.", "They are too small for the sorting mechanisms.", "They pose a severe **safety hazard** to sanitation and sorting workers.", "They contain hazardous chemicals."],
        "correct": 2,
        "explanation": "Sharps must be placed in a rigid, puncture-proof container and sealed/labeled before disposal to protect the safety of all waste handlers."
      },
      {
        "question": "What is the recommended best practice for recycling plastic containers that previously held cleaning agents (e.g., bleach, oven cleaner)?",
        "options": ["Rinse the bottle thoroughly with water until it's clean.", "Only throw the bottle away, never recycle it.", "Recycle it without rinsing to save water.", "Pour the residue into the sewer before recycling."],
        "correct": 0,
        "explanation": "If the container is emptied and thoroughly rinsed, it can usually be safely recycled. Rinsing prevents chemical residue from creating a hazard and contaminating the plastic batch."
      },
      {
        "question": "Which of these is the **worst** way to dispose of unused prescription medication?",
        "options": ["Taking it to an authorized drug take-back location (e.g., pharmacy, police station).", "Mixing it with an undesirable substance (like coffee grounds or kitty litter) and sealing it in a bag before trashing it.", "Flushing it down the toilet.", "Checking local guidelines for disposal instructions."],
        "correct": 2,
        "explanation": "Flushing medication is the worst method as it introduces pharmaceutical chemicals into the water supply, which can harm aquatic ecosystems and public health."
      }
    ],
  };

  @override
  void initState() {
    super.initState();
    
    _quizTopics = fullQuizBank.keys.toList();
    _selectedTopic = _quizTopics.first;
    
    _loadInformation();
    _checkLoginStatus();
    _loadQuizQuestions();
  }

  void _loadQuizQuestions() {
    setState(() {
      _quizQuestions = fullQuizBank[_selectedTopic]!;
      _resetQuiz();
    });
  }

  Future<void> _loadInformation() async {
    try {
      final String fileContent = await rootBundle.loadString('lib/information.txt');
      setState(() {
        _informationText = fileContent;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading information file: $e');
      setState(() {
        _informationText = "Welcome! Learn about waste management, recycling, and composting to improve your score and help the environment. Recycling right prevents contamination and saves energy. (Fallback content)";
        _isLoading = false;
      });
    }
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final username = prefs.getString('username');
    setState(() {
      _isLoggedIn = token != null;
      _username = username;
    });
  }

  void _selectAnswer(int index) {
    if (_showFeedback) return;
    setState(() {
      _selectedAnswer = index.toString();
    });
  }

  void _nextQuestion() {
    setState(() {
      if (_showFeedback) {
        _showFeedback = false; 
        _selectedAnswer = null; 
        
        if (_currentQuestionIndex < _quizQuestions.length - 1) {
          _currentQuestionIndex++;
        } else {
          _quizCompleted = true;
          _submitScore();
        }
      } else {
        if (_selectedAnswer == null) return;
        
        final selectedIndex = int.parse(_selectedAnswer!);
        final currentQuestion = _quizQuestions[_currentQuestionIndex];
        
        final correctAnswerIndex = currentQuestion['correct'] as int; 
        final explanation = currentQuestion['explanation'] as String;
        final options = currentQuestion['options'] as List<String>;

        bool isCorrect = selectedIndex == correctAnswerIndex;

        if (isCorrect) {
          _score += 10;
          _feedbackMessage = 'Correct! 🎉\n\nExplanation: $explanation';
          _feedbackColor = Colors.green;
        } else {
          final correctOptionText = options[correctAnswerIndex];
          _feedbackMessage = 'Incorrect. The correct answer was: "$correctOptionText".\n\nExplanation: $explanation';
          _feedbackColor = Colors.red;
        }
        
        _showFeedback = true;
      }
    });
  }

  Future<void> _submitScore() async {
    if (!_isLoggedIn) return;
    
    try {
      final url = apiUri('/update-score'); 
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _username,
          'points': _score,
          'quiz_topic': _selectedTopic, 
        }),
      );
      
      if (response.statusCode == 200) {
        debugPrint('Score submitted successfully!');
      } else {
        debugPrint('Failed to submit score: ${response.body}');
      }
      
    } catch (e) {
      debugPrint('Error submitting score: $e');
    }
  }

  void _resetQuiz() {
    setState(() {
      _currentQuestionIndex = 0;
      _score = 0;
      _selectedAnswer = null;
      _quizCompleted = false;
      _showFeedback = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hasQuestions = _quizQuestions.isNotEmpty;
    final bool canDisplayCurrentQuestion = hasQuestions && _currentQuestionIndex < _quizQuestions.length;

    final Map<String, dynamic>? currentQuestion = canDisplayCurrentQuestion ? _quizQuestions[_currentQuestionIndex] : null;
    final List<String> currentOptions = currentQuestion != null ? currentQuestion['options'] as List<String> : [];
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Information & Quiz'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Information',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _informationText,
                            style: const TextStyle(fontSize: 16, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Knowledge Quiz',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              const Text(
                                'Select Topic:',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 16), 
                              Expanded( 
                                child: DropdownButton<String>(
                                  value: _selectedTopic,
                                  isExpanded: true, 
                                  icon: const Icon(Icons.arrow_drop_down),
                                  elevation: 16,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary, 
                                    fontSize: 16
                                  ),
                                  underline: Container(
                                    height: 2,
                                    color: Theme.of(context).colorScheme.secondary,
                                  ),
                                  onChanged: (_showFeedback || _quizCompleted) ? null : (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _selectedTopic = newValue;
                                        _loadQuizQuestions(); 
                                      });
                                    }
                                  },
                                  items: _quizTopics
                                      .map<DropdownMenuItem<String>>((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value, overflow: TextOverflow.ellipsis),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ), 

                          if (_showFeedback) 
                            Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: _feedbackColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(color: _feedbackColor),
                              ),
                              child: Text(
                                _feedbackMessage,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _feedbackColor,
                                ),
                              ),
                            ),
                          
                          if (!_quizCompleted && canDisplayCurrentQuestion) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Question ${_currentQuestionIndex + 1} of ${_quizQuestions.length}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            Text(
                              currentQuestion!['question'] as String,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            ...List.generate(
                              currentOptions.length,
                              (index) => Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: RadioListTile<String>(
                                  title: Text(currentOptions[index]),
                                  value: index.toString(),
                                  groupValue: _selectedAnswer,
                                  onChanged: _showFeedback ? null : (value) => _selectAnswer(index),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: (_selectedAnswer != null || _showFeedback) ? _nextQuestion : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.secondary,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(
                                  _showFeedback 
                                      ? (_currentQuestionIndex < _quizQuestions.length - 1 ? 'Next Question' : 'Finish Quiz')
                                      : 'Submit Answer',
                                ),
                              ),
                            ),
                          ] 
                          
                          else if (_quizCompleted) ...[
                            const Text(
                              'Quiz Completed! 🥳',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your Final Score: $_score points',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: _resetQuiz, 
                                  child: const Text('Retake Quiz'),
                                ),
                                const SizedBox(width: 16),
                                if (_isLoggedIn)
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.leaderboard),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => const ScoreboardPage(),
                                        ),
                                      );
                                    },
                                    label: const Text('Scoreboard'),
                                  ),
                              ],
                            ),
                          ] 
                          
                          else if (hasQuestions == false) ...[
                            const Text(
                              'No questions available for this topic.',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class TakePhotoPage extends StatefulWidget {
  const TakePhotoPage({super.key});

  @override
  State<TakePhotoPage> createState() => _TakePhotoPageState();
}

class _TakePhotoPageState extends State<TakePhotoPage> {
  Uint8List? _capturedImageBytes;
  String? _mlResult;
  String? _confidence;
  bool _isAnalyzing = false;
  String? _errorMessage;

  Future<void> _takePhoto() async {
    debugPrint('Take Photo button pressed!');
    final ImagePicker picker = ImagePicker();

    try {
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);

      if (photo != null) {
        debugPrint('Photo taken: ${photo.name}');
        final bytes = await photo.readAsBytes();
        setState(() {
          _capturedImageBytes = bytes;
          _mlResult = null;
          _confidence = null;
          _errorMessage = null;
        });
        
        await _analyzeImage(bytes, photo.name);
      } else {
        debugPrint('No photo was taken.');
      }
    } catch (e) {
      debugPrint('Error while taking photo: $e');
      setState(() {
        _errorMessage = 'Error taking photo: $e';
      });
    }
  }

  Future<void> _analyzeImage(Uint8List imageBytes, String filename) async {
    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final url = apiUri('/analyze-image');
      final request = http.MultipartRequest('POST', url);
      
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: filename.isNotEmpty ? filename : 'photo.jpg',
      ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        setState(() {
          _mlResult = data['predicted_class'];
          _confidence = (data['confidence'] * 100).toStringAsFixed(1);
          _isAnalyzing = false;
        });
      } else {
        final errorData = jsonDecode(responseBody);
        setState(() {
          _errorMessage = 'Analysis failed: ${errorData['error'] ?? responseBody}';
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error analyzing image: $e';
        _isAnalyzing = false;
      });
    }
  }

  void _clearImage() {
    setState(() {
      _capturedImageBytes = null;
      _mlResult = null;
      _confidence = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take a Photo'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Take Photo Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take a Photo'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Display captured image
            if (_capturedImageBytes != null) ...[
              Expanded(
                child: Column(
                  children: [
                    // Image display
                    Container(
                      width: double.infinity,
                      height: 300,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _capturedImageBytes!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Analysis status
                    if (_isAnalyzing) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text('Analyzing image...', style: TextStyle(fontSize: 16)),
                    ] else if (_mlResult != null) ...[
                      // ML Results
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.psychology, color: Colors.green, size: 32),
                            const SizedBox(height: 8),
                            Text(
                              'Analysis Result',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _mlResult!,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Confidence: ${_confidence}%',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_errorMessage != null) ...[
                      // Error display
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.error, color: Colors.red, size: 32),
                            const SizedBox(height: 8),
                            Text(
                              'Error',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.red.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    
                    // Clear button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _clearImage,
                        icon: const Icon(Icons.clear),
                        label: const Text('Take Another Photo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Instructions when no image
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Take a photo to analyze with AI',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ScoreboardPage extends StatefulWidget {
  const ScoreboardPage({super.key});

  @override
  State<ScoreboardPage> createState() => _ScoreboardPageState();
}

class _ScoreboardPageState extends State<ScoreboardPage> {
  List<Map<String, dynamic>> _scores = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchScores();
  }

  Future<void> _fetchScores() async {
    try {
      final url = apiUri('/scores');
      final response = await http.get(url);
      if (!mounted) return;    
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> scoresRaw = data['scores'] ?? [];
        final parsed = scoresRaw
            .whereType<Map<String, dynamic>>()
            .map((m) => {
                  'username': m['username'] ?? 'Unknown',
                  'points': (m['points'] is int)
                      ? m['points']
                      : int.tryParse('${m['points']}') ?? 0,
                })
            .toList();
        setState(() {
          _scores = parsed;
          _loading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load scores (${response.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Global Scoreboard'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : RefreshIndicator(
                  onRefresh: _fetchScores,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      _buildTopThree(context),
                      const SizedBox(height: 16),
                      _buildFullList(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTopThree(BuildContext context) {
    final top = _scores.take(3).toList();
    if (top.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget buildCard(int index, Map<String, dynamic> item, Color color, double elevation) {
      return Expanded(
        child: Card(
          color: color.withOpacity(0.1),
          elevation: elevation,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '#${index + 1}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${item['username']}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text('${item['points']} pts', style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      );
    }

    final Color gold = Colors.amber;
    final Color silver = Colors.blueGrey;
    final Color bronze = Colors.brown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Top 3', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            if (top.length >= 2) buildCard(1, top[1], silver, 1),
            const SizedBox(width: 8),
            buildCard(0, top[0], gold, 3),
            const SizedBox(width: 8),
            if (top.length >= 3) buildCard(2, top[2], bronze, 1),
          ],
        ),
      ],
    );
  }

  Widget _buildFullList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('All Rankings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: _scores.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = _scores[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.pinkAccent.withOpacity(0.15),
                child: Text('${index + 1}', style: const TextStyle(color: Colors.pinkAccent)),
              ),
              title: Text('${item['username']}'),
              trailing: Text('${item['points']} pts', style: const TextStyle(fontWeight: FontWeight.bold)),
            );
          },
        ),
      ],
    );
  }
}

class ProfilePage extends StatefulWidget {
  final bool isLoggedIn;
  final String? username;
  final Function(bool, String?) onUpdateLogin; 
  final Function() onLogout; 

  const ProfilePage({
    super.key,
    required this.isLoggedIn,
    this.username,
    required this.onUpdateLogin,
    required this.onLogout,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {

  @override
  void initState() {
    super.initState();
    if (widget.isLoggedIn) {
      _loadProfileData();
    }
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token != null) {
      try {
        final url = apiUri('/profile');
        final response = await http.get(
          url,
          headers: {
            'Authorization': token,
          },
        );
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            _bio = data['bio'] ?? '';
            _points = data['points'] ?? 0;
            _profilePhoto = data['profile_photo'];
            if (_bio != null && _bio!.isNotEmpty) {
              _bioController.text = _bio!;
            }
          });
        }
      } catch (e) {
        debugPrint('Error loading profile data: $e');
      }
    }
  }

  bool _isLogin = true; 
  String? _bio; 
  int _points = 0; 
  String? _profilePhoto; 

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  bool _isUsernamePromptVisible = false;

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_isLogin) {
      if (username.isEmpty || password.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please fill in all fields'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      debugPrint('Login button pressed');
      final response = await _sendToBackend(username: username, password: password, isLogin: true);
      if (response != null && response['token'] != null) {
        debugPrint('Login response: $response');
        debugPrint('Username from response: ${response['username']}');
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', response['token']);
        await prefs.setString('username', response['username'] ?? '');
        widget.onUpdateLogin(true, response['username']);

        setState(() {
          widget.onUpdateLogin(true, response['username']);
        });
        
        await _loadProfileData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login successful!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login failed. Please check your credentials.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      if (email.isEmpty || password.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please fill in all fields'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      debugPrint('Sign Up button pressed');
      final response = await _sendToBackend(email: email, password: password, isLogin: false);
      if (response != null) {
        setState(() {
          _isUsernamePromptVisible = true;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _sendToBackend({String? username, String? email, required String password, 
    required bool isLogin
  }) async {
    final url = apiUri('/${isLogin ? 'login' : 'signup'}');

    final body = isLogin 
      ? {'username': username, 'password': password}
      : {'email': email, 'password': password};

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      debugPrint('Success: ${response.body}');
      return jsonDecode(response.body);
    } else {
      debugPrint('Error: ${response.body}');
      return null;
    }
  }

  Future<void> _submitUsername() async {
    final email = _emailController.text;
    final username = _usernameController.text;

    if (username.isEmpty) {
      debugPrint('Username cannot be empty');
      return;
    }

    final url = apiUri('/username');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'username': username}),
    );

    if (response.statusCode == 200) {
      debugPrint('Username saved successfully');
      setState(() {
        _isUsernamePromptVisible = false;
        _isLogin = true; 
      });
      
      _passwordController.text = _passwordController.text; 
      _usernameController.text = username; 
      await _submit(); 
    } else {
      debugPrint('Error saving username: ${response.body}');
    }
  }

  Future<void> _updateProfile() async {
    final bio = _bioController.text;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final url = apiUri('/profile');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
      body: jsonEncode({'bio': bio, 'profile_photo': _profilePhoto}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _bio = bio;
        _points = data['points'] ?? 0;
      });
      debugPrint('Profile updated successfully');
    } else {
      debugPrint('Error updating profile: ${response.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Profile'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: () {
                    // add pfp func
                  },
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: _profilePhoto != null
                        ? NetworkImage(_profilePhoto!)
                        : null,
                    child: _profilePhoto == null ? const Icon(Icons.person, size: 50) : null,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Username: ${widget.username ?? 'Unknown'}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _bioController,
                decoration: InputDecoration(
                  labelText: 'Bio',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _updateProfile,
                  child: const Text('Save Profile'),
                ),
              ),
              const SizedBox(height: 20),
              Text('Points: $_points', style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: widget.onLogout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Logout'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isUsernamePromptVisible) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = true;
                      });
                    },
                    child: Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _isLogin ? Colors.pinkAccent : Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = false;
                      });
                    },
                    child: Text(
                      'Sign Up',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: !_isLogin ? Colors.pinkAccent : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _isLogin ? _usernameController : _emailController,
                decoration: InputDecoration(
                  labelText: _isLogin ? 'Username' : 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _submit,
                  child: Text(_isLogin ? 'Login' : 'Sign Up'),
                ),
              ),
            ] else ...[
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Create a Username',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _submitUsername,
                  child: const Text('Save Username'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}