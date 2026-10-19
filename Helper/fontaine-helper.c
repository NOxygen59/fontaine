// Fontaine's root helper. iPadOS installs fonts for the whole system (CTFontManager, persistent
// scope) only from inside the installing app's bundle, which TrollStore leaves read-only for the
// app: Fontaine runs this as root (TrollStore's persona entitlement) to put a copy of a font in
// Fontaine.app/Fonts, or to take it away.
//
//   fontaine-helper put <name>      the font's data on standard input (Fontaine opens its own copy)
//   fontaine-helper delete <name>
//
// It only ever touches Fonts/ next to itself, by a plain file name with a font extension, and never
// opens a path it's given: whoever runs it can't make it read or write anything else.

#include <errno.h>
#include <fcntl.h>
#include <libgen.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/clonefile.h>
#include <sys/stat.h>
#include <unistd.h>

// The largest font files (CJK collections) are tens of megabytes.
static const off_t maxSize = 512LL * 1024 * 1024;

static int fail(const char *what) {
    fprintf(stderr, "%s: %s\n", what, strerror(errno));
    return 1;
}

static int validName(const char *name) {
    size_t n = strlen(name);
    if (n == 0 || n > 200 || name[0] == '.' || strchr(name, '/')) return 0;
    const char *ext = strrchr(name, '.');
    const char *allowed[] = {".ttf", ".otf", ".ttc", ".otc"};
    for (size_t i = 0; ext && i < sizeof allowed / sizeof *allowed; i++) {
        if (strcasecmp(ext, allowed[i]) == 0) return 1;
    }
    return 0;
}

// Fonts/ next to this executable (made if needed), opened; -1 on failure.
static int fontsFolder(void) {
    char path[PATH_MAX], real[PATH_MAX];
    uint32_t size = sizeof path;
    if (_NSGetExecutablePath(path, &size) != 0 || !realpath(path, real)) return -1;
    int bundle = open(dirname(real), O_RDONLY | O_DIRECTORY);
    if (bundle < 0) return -1;
    if (mkdirat(bundle, "Fonts", 0755) != 0 && errno != EEXIST) {
        close(bundle);
        return -1;
    }
    int fonts = openat(bundle, "Fonts", O_RDONLY | O_DIRECTORY | O_NOFOLLOW);
    close(bundle);
    return fonts;
}

// A plain copy of standard input, when it can't be cloned (another volume).
static int copyInput(int folder, const char *temp) {
    int out = openat(folder, temp, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0644);
    if (out < 0) return fail("create");
    static char buffer[1 << 16];
    ssize_t n;
    while ((n = read(STDIN_FILENO, buffer, sizeof buffer)) > 0) {
        for (ssize_t done = 0; done < n;) {
            ssize_t w = write(out, buffer + done, (size_t)(n - done));
            if (w < 0) {
                close(out);
                return fail("write");
            }
            done += w;
        }
    }
    if (n < 0) {
        close(out);
        return fail("read");
    }
    return close(out) == 0 ? 0 : fail("write");
}

static int put(int folder, const char *name) {
    struct stat st;
    if (fstat(STDIN_FILENO, &st) != 0) return fail("input");
    if (!S_ISREG(st.st_mode) || st.st_size <= 0 || st.st_size > maxSize) {
        fprintf(stderr, "input: not a font file\n");
        return 1;
    }
    char temp[256];
    snprintf(temp, sizeof temp, ".%s.part", name);
    unlinkat(folder, temp, 0);
    // A clone takes no space (the app's copy is on the same volume); owned by root, like the bundle.
    if (fclonefileat(STDIN_FILENO, folder, temp, CLONE_NOOWNERCOPY) != 0 && copyInput(folder, temp) != 0) {
        unlinkat(folder, temp, 0);
        return 1;
    }
    int fd = openat(folder, temp, O_RDONLY | O_NOFOLLOW);
    if (fd < 0 || fchmod(fd, 0644) != 0 || renameat(folder, temp, folder, name) != 0) {
        int status = fail("finish");
        if (fd >= 0) close(fd);
        unlinkat(folder, temp, 0);
        return status;
    }
    close(fd);
    return 0;
}

static int delete(int folder, const char *name) {
    if (unlinkat(folder, name, 0) != 0 && errno != ENOENT) return fail("delete");
    return 0;
}

int main(int argc, char *argv[]) {
    if (argc != 3 || !validName(argv[2])) {
        fprintf(stderr, "usage: fontaine-helper put|delete <name.ttf|otf|ttc|otc>\n");
        return 2;
    }
    int folder = fontsFolder();
    if (folder < 0) return fail("Fonts");
    if (strcmp(argv[1], "put") == 0) return put(folder, argv[2]);
    if (strcmp(argv[1], "delete") == 0) return delete(folder, argv[2]);
    fprintf(stderr, "unknown command: %s\n", argv[1]);
    return 2;
}
