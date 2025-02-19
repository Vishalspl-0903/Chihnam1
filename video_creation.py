from flask import Flask, render_template, request, jsonify, url_for
import os
import random
import numpy as np
import imageio.v2 as imageio
from PIL import Image, ImageDraw, ImageFont
from gtts import gTTS
import time
from werkzeug.utils import secure_filename

# Path to dataset
DATASET_FOLDER = r"C:\Users\visha\Downloads\archive (27)\asl_dataset"
STATIC_FOLDER = "static"

app = Flask(__name__, static_folder=STATIC_FOLDER)

# Ensure dataset folder exists
if not os.path.exists(DATASET_FOLDER):
    raise FileNotFoundError(f"Dataset folder '{DATASET_FOLDER}' not found!")

# Function to get a random image from each folder
def list_images_from_folders():
    characters = [str(i) for i in range(10)] + [chr(i) for i in range(ord('a'), ord('z') + 1)]
    images_dict = {}
    
    for char in characters:
        char_folder = os.path.join(DATASET_FOLDER, char)
        if os.path.exists(char_folder):
            images = [img for img in os.listdir(char_folder) if img.lower().endswith((".jpg", ".png", ".jpeg", ".bmp"))]
            if images:
                images_dict[char] = os.path.join(char_folder, random.choice(images))
    
    return images_dict

# Overlay text on image
def overlay_text_on_image(image_path, text, font_path="arial.ttf", font_size=40):
    if not os.path.exists(image_path):
        return None

    img = Image.open(image_path)
    draw = ImageDraw.Draw(img)

    try:
        font = ImageFont.truetype(font_path, font_size)
    except IOError:
        font = ImageFont.load_default()

    if hasattr(draw, "textbbox"):
        text_bbox = draw.textbbox((0, 0), text, font=font)
        text_width, text_height = text_bbox[2] - text_bbox[0], text_bbox[3] - text_bbox[1]
    else:
        text_width, text_height = font.getsize(text)  # Fallback for older Pillow versions

    width, height = img.size
    text_position = (width - text_width - 10, 30)
    
    draw.text(text_position, text, font=font, fill=(255, 255, 255))
    return np.array(img)

# Convert text to speech
def text_to_speech(text):
    timestamp = int(time.time())
    audio_filename = secure_filename(f"speech_{timestamp}.mp3")
    audio_path = os.path.join(app.static_folder, audio_filename)

    # Cleanup old audio files
    for file in os.listdir(app.static_folder):
        if file.startswith("speech_") and file.endswith(".mp3"):
            os.remove(os.path.join(app.static_folder, file))

    tts = gTTS(text=text, lang='en')
    tts.save(audio_path)
    
    return url_for('static', filename=audio_filename, _external=True)

# Generate ASL video
def generate_video(text_input):
    timestamp = int(time.time())
    output_video = os.path.join(app.static_folder, f"asl_output_{timestamp}.mp4")
    
    images_list = list_images_from_folders()
    fps = 3
    
    with imageio.get_writer(output_video, fps=fps) as writer:
        for word in text_input.split():
            word_display = ""
            for char in word:
                if char.isalnum():
                    image_path = images_list.get(char)
                    if image_path:
                        print(f"Processing character: {char}, image: {image_path}")
                        word_display += char
                        img_with_text = overlay_text_on_image(image_path, word_display, font_size=60)
                        if img_with_text is not None:
                            writer.append_data(img_with_text)
            
            # Add blank frames to separate words
            black_frame = np.zeros((img_with_text.shape[0], img_with_text.shape[1], 3), dtype=np.uint8)
            for _ in range(5):  
                writer.append_data(black_frame)
    
    return url_for('static', filename=os.path.basename(output_video), _external=True)

@app.route("/", methods=["GET", "POST"])
def index():
    video_url = None
    audio_url = None

    if request.method == "POST":
        text_input = request.form.get("text_input", "").lower()
        
        if text_input:
            video_url = generate_video(text_input)
            audio_url = text_to_speech(text_input)
    
    return render_template("index.html", video_url=video_url, audio_url=audio_url)

@app.route("/generate", methods=["POST"])
def generate():
    data = request.get_json()
    text_input = data.get("text", "").lower()
    
    if not text_input:
        return jsonify({"error": "No text provided"}), 400
    
    video_url = generate_video(text_input)
    audio_url = text_to_speech(text_input)
    
    return jsonify({"video_url": video_url, "audio_url": audio_url})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)