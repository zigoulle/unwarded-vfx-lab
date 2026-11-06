# What differs in the browser

The [web version](https://zigoulle.github.io/unwarded-vfx-lab/) is the same lab, exported by Godot for the browser. Browsers give a game less than a desktop does, so a few things differ. Everything here was checked on the published build; the desktop version (run from Godot, [guide part 2](guide.md#on-your-computer)) has none of these limits.

| What | In the browser | Why |
|---|---|---|
| **Renderer** | Godot's Compatibility renderer (WebGL 2) instead of Forward+. The effects, the Mage and the arena all draw, but light and glow are simpler: the lava's glow and the bloom knob look softer, and the arena's many lava lights are fewer per object. | WebGL 2 is the only 3D the browser export has. |
| **GPU cost (C)** | The measure reads 0 ms: the browser does not report GPU time. The particle, layer and triangle counts and the budget line still work. | WebGL gives no GPU timer queries to Godot. |
| **Saved presets** | Save, Duplicate and Rename work, but the presets are kept in the browser's own storage for this site: they are there next visit in the same browser, nowhere else, and clearing the site's data removes them. The presets that ship with the lab cannot be renamed or overwritten (a save under the same name keeps your copy first). **Copy** puts a preset's text on the clipboard to keep it. | A web page cannot write files on your disk. |
| **Tuning pages** | Read as they shipped. The reach slider works as on desktop (it never writes the page anyway). | The pages are packed inside the web build. |
| **Threads** | The build runs on one thread. | A threaded build needs the server to send two security headers (COOP and COEP), and GitHub Pages cannot send them. One thread is plenty for the lab. |
| **Sound** | None (the lab has none on desktop either). | |
| **Phones and tablets** | Not supported: the lab needs a keyboard, and its textures use a compression desktop graphics cards read. | |
| **First load** | About 65 MB (the engine and the lab's textures); the browser keeps it after that. | |

If something else looks broken in your browser, try Chrome or Edge first (the best-supported for WebGL 2), and check the browser's console (F12) for errors.
