### Chihnam
### Clone the repository
git clone https://github.com/Vishalspl-0903/Chihnam1.git
cd Chihnam1

### Backend (Flask) Setup
cd backend
pip install flask pillow gtts numpy imageio werkzeug

### Set the dataset path in app.py
Modify the line:
DATASET_FOLDER = "path_to_your_asl_dataset"

### Run the Flask server
python video_creation.py

Server will start at:
http://127.0.0.1:5000/

### Frontend (Flutter) Setup
cd ../frontend

### Install Flutter dependencies
flutter pub get

### Update the Flask server URL in Flutter code(ipv4)
Modify in generateASLVideo() function:
Uri.parse("http://your_server_ip:5000/generate")

### Run the Flutter app
flutter run
