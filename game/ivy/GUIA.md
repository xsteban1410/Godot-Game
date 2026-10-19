# Ivy: cómo cambiar lo que dice

Todo lo que dice Ivy está en **`lineas.json`**, en esta misma carpeta. Puedes cambiar cualquier frase o añadir
preguntas nuevas sin tocar el código. El juego lee el archivo al arrancar, también en las versiones exportadas
para Windows y Linux.

Las voces son archivos `.ogg` de la carpeta `voz/`. Si cambias una frase y no la vuelves a grabar, Ivy la
muestra escrita, pero sin voz. Nunca suena con el audio de la frase vieja.

## Qué hay en `lineas.json`

| Parte | Qué es |
|---|---|
| `pronunciacion` | Palabras que la voz lee mal y cómo deben sonar. Ejemplo: `"Ivy": "Iví"`. Solo cambia el audio; en pantalla se ve la palabra original. |
| `general` → `ayuda` | Lo que dice Ivy al abrir su panel con **F** (**Y** en el mando). |
| `general` → `boton_despues`, `boton_cerrar` | Texto de los dos botones fijos del panel. Solo se leen; no tienen voz. |
| `historia` | Respuestas a «¿Qué hago después?». Ivy elige una según cómo vaya la partida: `estrellas` (faltan piezas del cohete), `lanzar` (cohete completo), `hielo` (en la Luna, faltan retos), `volver` (en la Luna, retos hechos) y `todo` (misión cumplida). |
| `zonas` | Un bloque por cada lugar del juego, con su `saludo` y sus `preguntas`. |

Dentro de cada zona:

- `lugar`: solo es una nota para ti, el juego no la usa.
- `saludo`: lo que dice Ivy la primera vez que pisas esa zona en cada partida.
- `preguntas`: los botones del panel F en esa zona. Cada una tiene una `pregunta` (el texto del botón) y una
  `respuesta` (lo que dice Ivy). Puedes poner tantas como quieras, en el orden en que quieras que salgan.

## Las zonas

| Nombre en el JSON | Dónde |
|---|---|
| `city` | Calles de la ciudad. Su saludo es la bienvenida: suena siempre primero al empezar. |
| `plaza` | Plaza central con el holograma del STEAM LAB. |
| `solar`, `bridge`, `robotics`, `recycling` | Distritos de Energía solar, Ingeniería, Robótica y Reciclaje. |
| `math`, `vision`, `ai` | Retos del laboratorio: Matemáticas, Visión IA y Desafío IA. |
| `rocket` | Plataforma de lanzamiento del cohete. |
| `moon` | La Luna. Su saludo suena al aterrizar, antes que ningún otro. |
| `moon_jump`, `moon_rover`, `moon_power`, `moon_water` | Retos lunares: cráter del hielo, rover, energía de la base y purificador. |

No cambies estos nombres: el juego busca las zonas por ellos. Para crear una zona nueva hace falta una línea de
código en `world/city.gd` o `world/moon.gd` (`ivy.zone("nombre", centro, radio)`), además de su bloque en el JSON.

## Ejemplos

Cambiar un saludo: edita el texto entre comillas.

```json
"saludo": "¡Este es el distrito de reciclaje! Recoge los residuos y lánzalos a la caneca correcta.",
```

Añadir una pregunta a una zona: pon una coma después de la última `}` de la lista y añade otra igual.

```json
"preguntas": [
  { "pregunta": "¿Qué hago aquí?", "respuesta": "Usa el atril para empezar." },
  { "pregunta": "¿Quién inventó el reciclaje?", "respuesta": "Nadie en concreto: reutilizar es tan antiguo como las personas." }
]
```

Arreglar una pronunciación: añade la palabra a `pronunciacion`, escrita como debe sonar.

```json
"pronunciacion": { "Ivy": "Iví", "STEAM": "Estim", "LAB": "lab", "jetpack": "yetpak", "NOVA": "Nova" }
```

## Reglas del JSON (si las rompes, Ivy se queda callada)

- Todo texto va entre comillas dobles `"…"`. Si una frase necesita comillas, usa `«…»`.
- Separa los elementos con comas, pero **no pongas coma después del último** de una lista o un bloque.
- Las tildes, la ñ y los signos `¿ ¡` funcionan. Evita los emojis: la fuente del juego no los tiene y en algunos
  PC saldrían como cuadros.
- Para comprobar el archivo, pasa la autocomprobación (desde la carpeta del repo):
  `godot --headless --path game --script res://tests/selfcheck.gd`. Si el JSON está mal, avisa de qué falta.

## Consejos para que suene bien

- Frases cortas: dos o tres por respuesta. El bocadillo tiene sitio para unas 40 palabras.
- Escribe los números con letras («doce», no «12»): así suenan naturales.
- No nombres teclas (salvo F). Con mando no son las mismas, y el aviso del juego ya muestra la correcta.

## Volver a grabar las voces

Hace falta hacerlo después de cambiar el JSON. Solo se graban las frases nuevas o cambiadas, y los audios que ya
nadie usa se borran.

**Lo que necesitas** (una sola vez):

1. **Godot 4.7.**
2. **Piper**, la voz neuronal gratuita, que funciona sin internet:
   - Linux: `uv tool install piper-tts`
   - Windows: `pip install piper-tts`, o `uv tool install piper-tts`
3. **ffmpeg**:
   - Linux: `sudo pacman -S ffmpeg` o `sudo apt install ffmpeg`
   - Windows: `winget install ffmpeg`
4. **La voz de Ivy** (`es_AR-daniela-high`, licencia CC BY-SA 4.0). Descarga estos dos archivos en `art/voices/`,
   una carpeta al lado de `game/` (no se sube a GitHub porque pesa 115 MB):
   - https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_AR/daniela/high/es_AR-daniela-high.onnx
   - https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_AR/daniela/high/es_AR-daniela-high.onnx.json

**Grabar** (desde la carpeta del repo; en Windows, cambia `godot` por la ruta de tu `Godot_v4.7-…exe`):

```
godot --headless --path game --script res://tools/voice.gd
godot --headless --path game --import
```

Para grabar todo otra vez desde cero, por ejemplo tras cambiar la voz (`MODEL`), el ritmo (`PIPER`) o el
tratamiento del sonido (`EFFECT`) en `tools/voice.gd`, añade `-- --todo` al final de la primera orden. Después vuelve a exportar el juego para que las
builds lleven las voces nuevas.
