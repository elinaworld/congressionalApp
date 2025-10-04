from flask import Flask, request, jsonify
import jwt
import datetime
import json
import os
import torch
import torchvision.transforms as transforms
from PIL import Image
import io
import base64

app = Flask(__name__)

USERS_FILE = 'users_data.json'

def load_users():
    """Load users from file, return empty dict if file doesn't exist"""
    if os.path.exists(USERS_FILE):
        try:
            with open(USERS_FILE, 'r') as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            return {}
    return {}

def save_users():
    """Save users to file"""
    try:
        with open(USERS_FILE, 'w') as f:
            json.dump(users, f, indent=2)
    except IOError as e:
        print(f"Error saving users: {e}")

users = load_users()

# Load ML model
MODEL_PATH = 'best_model.pth'
model = None
model_loaded = False

def load_model():
    """Load the PyTorch model"""
    global model, model_loaded
    try:
        if os.path.exists(MODEL_PATH):
            model = torch.load(MODEL_PATH, map_location='cpu')
            model.eval()
            model_loaded = True
            print(f"Model loaded successfully from {MODEL_PATH}")
        else:
            print(f"Model file {MODEL_PATH} not found")
            model_loaded = False
    except Exception as e:
        print(f"Error loading model: {e}")
        model_loaded = False

# Load model on startup
load_model()

# Image preprocessing transforms
transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

@app.route('/signup', methods=['POST'])
def signup():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')

    if email in users:
        return jsonify({'error': 'User already exists'}), 400

    users[email] = {'password': password, 'username': None, 'bio': '', 'profile_photo': None, 'points': 0}
    save_users()
    return jsonify({'message': 'User signed up successfully'}), 200

SECRET_KEY = 'v8#hG@4$Lp9!_bA7%fJz^2wY6qX&rE5(C8dI-nK*mU+oP)'

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({'error': 'Username and password are required'}), 400

    user = next((u for u in users.values() if u['username'] == username), None)

    if not user or user['password'] != password:
        return jsonify({'error': 'Invalid credentials'}), 400

    token = jwt.encode(
        {'username': user['username'], 'exp': datetime.datetime.utcnow() + datetime.timedelta(days=7)},
        SECRET_KEY,
        algorithm='HS256'
    )
    return jsonify({'message': 'Login successful', 'token': token, 'username': user['username']}), 200

@app.route('/username', methods=['POST'])
def save_username():
    data = request.get_json()
    email = data.get('email')
    username = data.get('username')

    if email not in users:
        return jsonify({'error': 'User not found'}), 400

    users[email]['username'] = username
    save_users()
    return jsonify({'message': 'Username saved successfully'}), 200

def verify_token(token):
    try:
        decoded = jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
        return decoded['username']
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None

@app.route('/profile', methods=['GET', 'POST'])
def profile():
    token = request.headers.get('Authorization')
    if not token:
        return jsonify({'error': 'Token is missing'}), 401

    username = verify_token(token)
    if not username:
        return jsonify({'error': 'Invalid or expired token'}), 401

    user = next((u for u in users.values() if u['username'] == username), None)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    if request.method == 'GET':
        return jsonify({
            'username': username,
            'bio': user['bio'],
            'profile_photo': user['profile_photo'],
            'points': user['points']
        }), 200
    
    data = request.get_json()
    user['bio'] = data.get('bio', user['bio'])
    user['profile_photo'] = data.get('profile_photo', user['profile_photo'])
    save_users()

    return jsonify({
        'message': 'Profile updated successfully',
        'bio': user['bio'],
        'profile_photo': user['profile_photo'],
        'points': user['points']  
    }), 200

@app.route('/verify-token', methods=['POST'])
def verify_token_endpoint():
    token = request.headers.get('Authorization')
    if not token:
        return jsonify({'valid': False, 'error': 'Token is missing'}), 401

    username = verify_token(token)
    if not username:
        return jsonify({'valid': False, 'error': 'Invalid or expired token'}), 401

    return jsonify({'valid': True, 'username': username}), 200

@app.route('/scores', methods=['GET'])
def scores():
    leaderboard = [
        {
            'username': u.get('username'),
            'points': int(u.get('points', 0))
        }
        for u in users.values()
        if u.get('username')
    ]

    leaderboard.sort(key=lambda item: item['points'], reverse=True)

    return jsonify({'scores': leaderboard}), 200

@app.route('/update-points', methods=['POST'])
def update_points():
    token = request.headers.get('Authorization')
    if not token:
        return jsonify({'error': 'Token is missing'}), 401

    username = verify_token(token)
    if not username:
        return jsonify({'error': 'Invalid or expired token'}), 401

    user = next((u for u in users.values() if u['username'] == username), None)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    data = request.get_json()
    points_to_add = data.get('points', 0)
    
    if not isinstance(points_to_add, int):
        return jsonify({'error': 'Points must be an integer'}), 400
    
    user['points'] = user.get('points', 0) + points_to_add
    save_users()

    return jsonify({
        'message': 'Points updated successfully',
        'new_points': user['points']
    }), 200

@app.route('/analyze-image', methods=['POST'])
def analyze_image():
    """Analyze uploaded image with ML model"""
    try:
        if not model_loaded:
            return jsonify({'error': 'ML model not loaded'}), 500
        
        if 'image' not in request.files:
            return jsonify({'error': 'No image provided'}), 400
        
        file = request.files['image']
        if file.filename == '':
            return jsonify({'error': 'No image selected'}), 400
        
        image_data = file.read()
        image = Image.open(io.BytesIO(image_data)).convert('RGB')
        
        input_tensor = transform(image).unsqueeze(0)
        
        with torch.no_grad():
            outputs = model(input_tensor)
            probabilities = torch.nn.functional.softmax(outputs[0], dim=1)
            confidence, predicted_class = torch.max(probabilities, 1)
            
        confidence_score = confidence.item()
        predicted_class_id = predicted_class.item()

        if predicted_class_id in {1, 2, 3, 12, 13, 15, 16, 18, 20, 21, 24, 25, 26, 27, 28, 29, 32, 33, 34, 35, 36, 38, 39, 41}:
            predicted_label = "Recycle"
        elif predicted_class_id in {4, 17, 19, 22, 40}:
            predicted_label = "Compost"
        elif predicted_class_id in {5, 6, 7, 8, 9, 10, 11, 14, 23, 30, 31, 37}:
            predicted_label = "Trash"
        
        return jsonify({
            'success': True,
            'predicted_class': predicted_label,
            'confidence': round(confidence_score, 4),
            'class_id': predicted_class_id
        }), 200
        
    except Exception as e:
        print(f"Error analyzing image: {e}")
        return jsonify({'error': f'Image analysis failed: {str(e)}'}), 500

if __name__ == '__main__':
    app.run(debug=True)
