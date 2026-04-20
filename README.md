# [cite_start]Hadley Mission Control [cite: 1]

[cite_start]**Hadley Mission Control** is a real-time astronomical observation and telescope control interface built with **LÖVE**[cite: 2]. [cite_start]This tool is specifically calibrated for the **Hadley $114/900$ Newtonian Reflector**[cite: 3]. [cite_start]It synchronizes live ephemeris data with your local observation site to provide high-precision positioning for celestial bodies[cite: 5].

[cite_start]The interface includes a simulated eyepiece view that accounts for Newtonian inversion and magnification math based on your specific equipment configuration[cite: 6].

---

## Features

* [cite_start]**Horizons API Integration:** Asynchronous fetching of topocentric coordinates from NASA/JPL[cite: 8].
* [cite_start]**Optics Simulation:** Real-time magnification and True Field of View (TFOV) calculation[cite: 9].
* [cite_start]**Newtonian Inversion:** 180-degree image rotation simulation to match physical eyepiece output[cite: 10].
* [cite_start]**Planisphere Mapping:** Live altitude/azimuth grid with cardinal direction markers and targeting overlays[cite: 11].
* [cite_start]**Night Mode:** Luminance-to-Red channel filtering for dark-site preservation[cite: 12].
* [cite_start]**Coordinate Synchronization:** Automated observer location via IP-AΡΙ[cite: 13].

---

## Controls

### Navigation
* [cite_start]**TAB:** Toggle between the Observer Log and Equipment Specifications[cite: 16].
* [cite_start]**Mouse Click:** Select a celestial body from the sidebar to track[cite: 17].
* [cite_start]**N:** Toggle Night Mode (Red Filter)[cite: 18].
* [cite_start]**R:** Reset time offset to current UTC[cite: 19].

### Time & Optics
* [cite_start]**Left/Right Arrows:** Offset time by $+/-1$ hour[cite: 21].
* [cite_start]**[+]/[-] Keys:** Increment/Decrement eyepiece focal length (scales FOV live)[cite: 22].

---

## Technical Implementation

### [cite_start]Stencil Clipping [cite: 24]
[cite_start]The eyepiece view utilizes a GPU stencil buffer to ensure that planetary rendering is clipped strictly to the circular aperture of the simulated eyepiece[cite: 25]. [cite_start]This prevents UI bleed-over when viewing large objects like the Moon at high magnification[cite: 26].

### [cite_start]Threading [cite: 27]
[cite_start]Network requests to NASA's Horizons system are handled in a separate thread to prevent UI blocking during data fetch cycles[cite: 28].

---

## [cite_start]Installation [cite: 29]

1. [cite_start]Ensure the **LÖVE engine** (11.x or higher) is installed[cite: 30].
2. [cite_start]Clone the repository[cite: 31].
3. [cite_start]Run the application using `love` in the project directory[cite: 32].

---

## [cite_start]Configuration [cite: 33]

[cite_start]Default constants can be modified at the top of `main.lua`[cite: 34]:

| Constant | Description | Default Value |
| :--- | :--- | :--- |
| `SCOPE_FL` | Primary mirror focal length | [cite_start]900mm [cite: 35] |
| `EYEPIECE_FL` | Default eyepiece focal length | [cite_start]9mm [cite: 35] |
| `EYEPIECE_AFOV` | Apparent Field of View of your eyepiece | [cite_start]66° [cite: 35] |

---
[cite_start]*Hadley 114/900 Mission Control Documentation 2026* [cite: 36]
