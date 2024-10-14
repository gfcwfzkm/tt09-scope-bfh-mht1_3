import cv2
from cv2_enumerate_cameras import enumerate_cameras
import os
import tkinter as tk
from PIL import Image, ImageTk

def update_frame():
	ret, frame = cap.read()

	if ret:
		# Rotate the frame 90 degrees counterclockwise
		rotated_frame = cv2.rotate(frame, cv2.ROTATE_90_COUNTERCLOCKWISE)

		# Get the size of the Tkinter window
		window_width = label.winfo_width() or 64
		window_height = label.winfo_height() or 480
		resized_frame = cv2.resize(rotated_frame, (window_width, window_height))

		# Convert the image from BGR (OpenCV format) to RGB
		frame_rgb = cv2.cvtColor(resized_frame, cv2.COLOR_BGR2RGB)

		# Convert the image to a PIL format and then to ImageTk format
		img = Image.fromarray(frame_rgb)
		imgtk = ImageTk.PhotoImage(image=img)

		# Update the Label widget with the new image
		label.imgtk = imgtk
		label.configure(image=imgtk)

	# Call the update_frame function after 10 ms to continuously update the frame
	label.after(10, update_frame)


# Get a list of available cameras if there are multiple
useCamera = None
if os.name == 'nt':
	if len(enumerate_cameras(cv2.CAP_DSHOW)) > 1:
		for camera_info in enumerate_cameras(cv2.CAP_MSMF):
			print(f'{camera_info.index}: {camera_info.name}')
	else:
		useCamera = 0
else:
	if len(enumerate_cameras(cv2.CAP_GSTREAMER)) > 1:
		for camera_info in enumerate_cameras(cv2.CAP_GSTREAMER):
			print(f'{camera_info.device_path}: {camera_info.card}')
	else:
		useCamera = 0

if useCamera is None:
	useCamera = input("Which camera would you like to use? ")

# Create a Tkinter window
root = tk.Tk()
root.title("Oscilloscope")
root.geometry('640x480')
label = tk.Label(root)
label.pack(fill=tk.BOTH, expand=True)


# Open the default camera (camera 0)
cap = cv2.VideoCapture(int(useCamera))

if not cap.isOpened():
	print("Error: Could not open camera.")
	exit()

# Start updating the camera feed
update_frame()

# Run the Tkinter main loop
root.mainloop()

# Release the camera when the window is closed
cap.release()
cv2.destroyAllWindows()
