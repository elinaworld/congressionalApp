from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import os
import jwt
import datetime

app = Flask(__name__)
CORS(app)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SEED_USERS_FILE = os.path.join(BASE_DIR, 'users_data.json')
USERS_FILE = os.environ.get('USERS_FILE', os.path.join('/tmp', 'users_data.json'))

def load_users():
    """Load users from file, return empty dict if file doesn't exist"""
    if not os.path.exists(USERS_FILE) and os.path.exists(SEED_USERS_FILE):
        try:
            with open(SEED_USERS_FILE, 'r') as src, open(USERS_FILE, 'w') as dst:
                dst.write(src.read())
        except IOError:
            pass
    if os.path.exists(USERS_FILE):
        try:
            with open(USERS_FILE, 'r') as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            return {}
    return {}

def save_users():
    """Save users to file"""
    global users
    try:
        with open(USERS_FILE, 'w') as f:
            json.dump(users, f, indent=2)
    except IOError as e:
        print(f"Error saving users: {e}")

users = load_users()

@app.route('/')
def index():
    from flask import redirect
    return redirect('/index.html')

MODEL_PATH = os.path.join(BASE_DIR, 'best_model.onnx')
onnx_session = None
model_loaded = False

RECYCLE_IDS = {1, 2, 3, 12, 13, 15, 16, 18, 20, 21, 24, 25, 26, 27, 28, 29, 32, 33, 34, 35, 36, 38, 39, 41}
COMPOST_IDS = {4, 17, 19, 22, 40}
TRASH_IDS = {0, 5, 6, 7, 8, 9, 10, 11, 14, 23, 30, 31, 37, 42, 43}


def load_model():
    """Load the ONNX model on first use (lazy load for serverless cold starts)."""
    global onnx_session, model_loaded
    if model_loaded:
        return True
    try:
        import onnxruntime as ort
    except ImportError:
        print("onnxruntime not installed")
        model_loaded = False
        return False
    try:
        if os.path.exists(MODEL_PATH):
            onnx_session = ort.InferenceSession(
                MODEL_PATH,
                providers=['CPUExecutionProvider'],
            )
            model_loaded = True
            print(f"ONNX model loaded from {MODEL_PATH}")
        else:
            print(f"Model file {MODEL_PATH} not found")
            model_loaded = False
    except Exception as e:
        print(f"Error loading model: {e}")
        model_loaded = False
    return model_loaded


def preprocess_image(image):
    """Resize and normalize image to match training pipeline (Resize + ToTensor)."""
    import numpy as np
    image = image.convert('RGB').resize((300, 300))
    arr = np.array(image, dtype=np.float32) / 255.0
    arr = np.transpose(arr, (2, 0, 1))
    return np.expand_dims(arr, axis=0)


def predict_label(logits):
    import numpy as np
    shifted = logits - np.max(logits, axis=1, keepdims=True)
    probs = np.exp(shifted)
    probs = probs / probs.sum(axis=1, keepdims=True)
    predicted_class_id = int(np.argmax(probs, axis=1)[0])
    confidence_score = float(probs[0, predicted_class_id])
    if predicted_class_id in RECYCLE_IDS:
        predicted_label = "Recycle"
    elif predicted_class_id in COMPOST_IDS:
        predicted_label = "Compost"
    elif predicted_class_id in TRASH_IDS:
        predicted_label = "Trash"
    else:
        predicted_label = "Unknown"
    return predicted_label, confidence_score, predicted_class_id

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

SECRET_KEY = os.environ.get('SECRET_KEY', 'v8#hG@4$Lp9!_bA7%fJz^2wY6qX&rE5(C8dI-nK*mU+oP)')

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
        if not load_model():
            return jsonify({'error': 'ML model could not be loaded'}), 503
        
        import io
        from PIL import Image
        
        if 'image' not in request.files:
            return jsonify({'error': 'No image provided'}), 400
        
        file = request.files['image']
        if file.filename == '':
            return jsonify({'error': 'No image selected'}), 400
        
        image_data = file.read()
        image = Image.open(io.BytesIO(image_data))
        input_array = preprocess_image(image)
        input_name = onnx_session.get_inputs()[0].name
        outputs = onnx_session.run(None, {input_name: input_array})
        predicted_label, confidence_score, predicted_class_id = predict_label(outputs[0])
        
        return jsonify({
            'success': True,
            'predicted_class': predicted_label,
            'confidence': round(confidence_score, 4),
            'class_id': predicted_class_id
        }), 200
        
    except Exception as e:
        print(f"Error analyzing image: {e}")
        return jsonify({'error': f'Image analysis failed: {str(e)}'}), 500

@app.route('/update-score', methods=['POST'])
def update_score():
    global users 
    
    try:
        data = request.get_json()
        username = data.get('username')
        points = data.get('points', 0)
        
        if not username:
            return jsonify({'error': 'Username is required'}), 400
        
        users = load_users()

        user_object = next((u for u in users.values() if u.get('username') == username), None)

        if user_object:
            user_object['points'] = user_object.get('points', 0) + points
            save_users()
            return jsonify({'success': True, 'new_score': user_object['points']}), 200
        else:
            return jsonify({'error': 'User not found'}), 404
            
    except Exception as e:
        print(f"Error in update_score: {e}")
        return jsonify({'error': f'An unexpected error occurred: {str(e)}'}), 500

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=8000)
