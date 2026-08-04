# agent-devtools.nix

A curated collection of Nix packages for agent development tools.

## Packages

- `omnigraph`
- `omnigraph-cli`
- `omnigraph-server`

Build a package with:

```console
nix build .#omnigraph
```

## NixOS modules

The flake exports `nixosModules.omnigraph` for running the Omnigraph server.

```nix
{
  inputs.agent-devtools.url = "github:mulatta/agent-devtools.nix";

  outputs = { agent-devtools, nixpkgs, ... }: {
    nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      modules = [
        agent-devtools.nixosModules.omnigraph
        {
          services.omnigraph = {
            enable = true;
            cluster = "/var/lib/omnigraph/cluster";
          };
        }
      ];
    };
  };
}
```

## Development

```console
nix develop
nix flake check
```
