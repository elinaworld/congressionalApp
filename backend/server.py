from flask import Flask, request, jsonify
import jwt
import datetime

app = Flask(__name__)

users = {}

@app.route('/signup', methods=['POST'])
def signup():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')

    if email in users:
        return jsonify({'error': 'User already exists'}), 400

    users[email] = {'password': password, 'username': None, 'bio': '', 'profile_photo': None, 'points': 0}
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

if __name__ == '__main__':
    app.run(debug=True)
