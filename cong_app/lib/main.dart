import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:http/http.dart' as http; 
import 'dart:convert'; 
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
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
      final url = Uri.parse('http://127.0.0.1:5000/verify-token');
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
      const Center(child: Text('Home Page', style: TextStyle(fontSize: 24))),
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

class TakePhotoPage extends StatelessWidget {
  const TakePhotoPage({super.key});

  Future<void> _takePhoto() async {
    debugPrint('Take Photo button pressed!');
    final ImagePicker picker = ImagePicker();

    try {
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);

      if (photo != null) {
        debugPrint('Photo taken: ${photo.path}');
      } else {
        debugPrint('No photo was taken.');
      }
    } catch (e) {
      debugPrint('Error while taking photo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take a Photo'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Center(
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
        final url = Uri.parse('http://127.0.0.1:5000/profile');
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
    final url = Uri.parse('http://127.0.0.1:5000/${isLogin ? 'login' : 'signup'}');

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

    final url = Uri.parse('http://127.0.0.1:5000/username');
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

    final url = Uri.parse('http://127.0.0.1:5000/profile');
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