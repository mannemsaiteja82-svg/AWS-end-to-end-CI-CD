from flask import Flask, render_template # 👈 Added render_template

app = Flask(__name__)

@app.route('/')
def home():
    # Renders your new polished index.html page automatically
    return render_template('index.html') 

if __name__ == '__main__':
    # Keeps your fixed public networking configuration active!
    app.run(host='0.0.0.0', port=5000)
