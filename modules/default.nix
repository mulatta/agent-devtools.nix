{ self }:
{
  omnigraph =
    {
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ ./omnigraph ];

      services.omnigraph.package =
        lib.mkDefault
          self.packages.${pkgs.stdenv.hostPlatform.system}.omnigraph-server;
    };
}
