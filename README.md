# Hadley Mission Control

**Hadley Mission Control** is a real-time astronomical observation and telescope control interface built with **LÖVE**. This tool is specifically calibrated for the **Hadley 114/900 Newtonian Reflector**. It synchronizes live ephemeris data with your local observation site to provide high-precision positioning for celestial bodies.

The interface includes a simulated eyepiece view that accounts for Newtonian inversion and magnification math based on your specific equipment configuration.

---

## Features

* **Horizons API Integration:** Asynchronous fetching of topocentric coordinates from NASA/JPL.
* **Optics Simulation:** Real-time magnification and True Field of View (TFOV) calculation.
* **Newtonian Inversion:** 180-degree image rotation simulation to match physical eyepiece output.
* **Planisphere Mapping:** Live altitude/azimuth grid with cardinal direction markers and targeting overlays.
* **Night Mode:** Luminance-to-Red channel filtering for dark-site preservation.
* **Coordinate Synchronization:** Automated observer location via IP-API.

---

## Controls

### Navigation
* **Mouse Click:** Select a celestial body from the sidebar to track.
* **N:** Toggle Night Mode (Red Filter).
* **R:** Reset time offset to current UTC.

### Time & Optics
* **Left/Right Arrows:** Offset time by +/- 1 hour.
* **[+]/[-] Keys:** Increment/Decrement eyepiece focal length (scales FOV live).

---

## Technical Implementation

### Threading
Network requests to NASA's Horizons system are handled in a separate thread to prevent UI blocking during data fetch cycles.

---

#### Theres alot of useless files , don't worry about it its just for personal testing and i never actually deleted them because they can always be usefull, just download the release !

*Hadley 114/900 Mission Control Documentation 2026
