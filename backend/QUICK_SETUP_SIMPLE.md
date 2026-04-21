# Quick Setup - Simplified Virtual Try-On

## ⚠️ File to Use: `api_server_simple.py` (NOT `api_server.py`)

---

## ✅ What This Does

This simplified version gives you **working virtual try-on RIGHT NOW** without needing ML models. It uses smart image overlay to composite clothing onto person photos.

**Perfect while you wait to get the models from your friend!**

---

## 🚀 Quick Start (5 Minutes)

### Step 1: Install Python Dependencies

```bash
cd backend
pip install -r requirements_simple.txt
```

### Step 2: Start the Server

**Option A - Windows:**
```bash
start_simple.bat
```

**Option B - Manual:**
```bash
python api_server.py
```

### Step 3: Test the Server

Open your browser: **http://localhost:8000**

You should see:
```json
{
  "status": "running",
  "service": "Virtual Try-On API",
  "version": "1.0.0",
  "mode": "Simplified Overlay",
  "ml_models_available": false
}
```

### Step 4: Update Flutter App

1. Find your computer's IP address:
   ```bash
   ipconfig
   ```
   Look for "IPv4 Address" (e.g., 192.168.1.100)

2. Open `lib/services/virtual_tryon_service.dart`
3. Update line 11:
   ```dart
   static const String baseUrl = 'http://YOUR_IP:8000';
   ```

4. Run your Flutter app:
   ```bash
   flutter run
   ```

---

## 🎯 How to Use in App

1. Open a product with AR badge
2. Tap "Try This On"
3. Take/select a photo
4. Select the product
5. Wait 2-3 seconds
6. See the result!

**Processing time: 2-3 seconds** (much faster than ML pipeline!)

---

## 📊 What You Get

### Simplified Mode (Current):
- ✅ **Works immediately** - No setup needed
- ✅ **Fast** - Results in 2-3 seconds
- ✅ **No GPU required** - Runs on any PC
- ⚠️ **Basic overlay** - Simple image composite
- 📸 Good enough for demos and testing

### Full ML Mode (When you get models):
- ✅ **Photorealistic results**
- ✅ **Perfect clothing fit**
- ✅ **Natural lighting/shadows**
- ⏱️ Takes 2-3 minutes
- 🎯 Professional quality

---

## 🔄 Switching to Full Mode Later

When you get the models folder from your friend:

1. Copy `models/` folder to `backend/models/`
2. Update CONFIG paths in `api_server.py`
3. Restart server with `python api_server.py`

**That's it!** The server will automatically detect models and use the full ML pipeline. No Flutter code changes needed!

---

## ✅ Verification Checklist

- [ ] Python dependencies installed
- [ ] Server starts without errors
- [ ] Browser shows "Simplified Overlay" mode
- [ ] Flutter app connects to server
- [ ] Can upload images in app
- [ ] Results appear in 2-3 seconds

---

## 🐛 Troubleshooting

**Server won't start?**
```bash
pip install --upgrade fastapi uvicorn pillow
```

**Flutter can't connect?**
- Check firewall
- Verify IP address is correct
- Make sure phone and PC on same WiFi
- Try `http://localhost:8000` if testing on PC

**Images not processing?**
- Check backend console for errors
- Verify images are JPG/PNG
- Try smaller image files

---

## 💡 Tips

1. **Use front-facing camera** for best results
2. **Plain background** works better
3. **Full body photos** show more of the clothing
4. **Good lighting** improves quality

---

## 📝 What's Next?

1. ✅ Get simplified version working (you are here!)
2. 📞 Contact friend for models folder
3. 🔧 Switch to full ML pipeline
4. 🚀 Deploy to production

---

## 🆘 Need Help?

**Check server logs** in the terminal where you ran `python api_server.py`

**Test API directly**: Visit http://localhost:8000/docs to try endpoints manually

**Current setup is preserved**: All your ML pipeline code is still there, just inactive until you add the models folder!

---

**Status**: ✅ Ready to use! Start the server and test in your app! 🎉
