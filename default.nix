let flake = import (./modules/internal/compat.nix) { src = ./.; }; in flake.defaultNix
