import os
import math
from PIL import Image, ImageDraw

def generate_sphere_obj(filepath):
    # Generates a simple UV sphere fitting in 1x1x1 (-0.5 to 0.5)
    rings = 16
    segments = 16
    radius = 0.5

    vertices = []
    uvs = []
    normals = []
    faces = []

    for i in range(rings + 1):
        v = i / rings
        phi = v * math.pi

        for j in range(segments + 1):
            u = j / segments
            theta = u * 2 * math.pi

            x = radius * math.sin(phi) * math.cos(theta)
            y = radius * math.cos(phi)
            z = radius * math.sin(phi) * math.sin(theta)

            vertices.append((x, y, z))
            normals.append((x/radius, y/radius, z/radius))
            uvs.append((u, v))

    for i in range(rings):
        for j in range(segments):
            p1 = i * (segments + 1) + j + 1
            p2 = p1 + 1
            p3 = (i + 1) * (segments + 1) + j + 1
            p4 = p3 + 1

            faces.append((p1, p2, p4, p3))

    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with open(filepath, 'w') as f:
        f.write("# Simple UV Sphere\n")
        for v in vertices:
            f.write(f"v {v[0]:.6f} {v[1]:.6f} {v[2]:.6f}\n")
        for vn in normals:
            f.write(f"vn {vn[0]:.6f} {vn[1]:.6f} {vn[2]:.6f}\n")
        for vt in uvs:
            f.write(f"vt {vt[0]:.6f} {vt[1]:.6f}\n")
        for face in faces:
            f.write(f"f {face[0]}/{face[0]}/{face[0]} {face[1]}/{face[1]}/{face[1]} {face[2]}/{face[2]}/{face[2]} {face[3]}/{face[3]}/{face[3]}\n")

def generate_base_texture(filepath):
    # Generates a 32x32 white texture with a simple radial gradient for 3D shading
    size = 32
    img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = size / 2, size / 2
    radius = size / 2

    for y in range(size):
        for x in range(size):
            dx = x - cx + 0.5
            dy = y - cy + 0.5
            dist = math.sqrt(dx*dx + dy*dy)
            if dist <= radius:
                # Basic shading: brighter in top-left, darker in bottom-right
                shade = 1.0 - (dist / radius) * 0.3
                if dx > 0 and dy > 0:
                    shade -= 0.2
                elif dx < 0 and dy < 0:
                    shade += 0.2

                shade = max(0.0, min(1.0, shade))
                v = int(255 * shade)
                img.putpixel((x, y), (v, v, v, 255))

    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    img.save(filepath)

def generate_spawner_texture(filepath):
    # Simple mechanical looking spawner texture
    size = 16
    img = Image.new("RGBA", (size, size), (100, 100, 100, 255))
    draw = ImageDraw.Draw(img)

    # Draw some mechanical lines
    draw.rectangle([1, 1, 14, 14], outline=(80, 80, 80, 255), fill=(120, 120, 120, 255))
    draw.rectangle([4, 4, 11, 11], outline=(50, 50, 50, 255), fill=(30, 30, 30, 255))

    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    img.save(filepath)

if __name__ == "__main__":
    generate_sphere_obj("models/ball.obj")
    generate_base_texture("textures/ball_base.png")
    generate_spawner_texture("textures/ball_spawner.png")
    print("Assets generated successfully.")
