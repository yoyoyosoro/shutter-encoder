import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.jar.*;

public class JarRepack {
    public static void main(String[] args) throws Exception {
        Path original = Path.of(args[0]), output = Path.of(args[1]), classes = Path.of(args[2]);
        try (JarFile input = new JarFile(original.toFile());
             JarOutputStream target = new JarOutputStream(Files.newOutputStream(output))) {
            for (JarEntry entry : Collections.list(input.entries())) {
                String name = entry.getName();
                if (name.startsWith("shutterencoder/") || name.matches("META-INF/[^/]+\\.(SF|RSA|DSA)")) continue;
                target.putNextEntry(new JarEntry(name));
                if (!entry.isDirectory()) {
                    try (InputStream source = input.getInputStream(entry)) { source.transferTo(target); }
                }
                target.closeEntry();
            }
            try (var paths = Files.walk(classes)) {
                for (Path file : paths.filter(Files::isRegularFile).toList()) {
                    target.putNextEntry(new JarEntry(classes.relativize(file).toString().replace('\\', '/')));
                    Files.copy(file, target);
                    target.closeEntry();
                }
            }
        }
        System.out.println("REPACK_OK " + output);
    }
}
