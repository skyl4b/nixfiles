let
  # Shared activation identity, provisioned privately on each host.
  shared = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGtYEorydU+kEkrKetB7mOoPIbjiiEUBEihvdkEFCRa6 nixfiles-secrets";
  # Personal identity retained for recovery and editing secrets.
  recovery = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAknKoOCh4U3ZQK839e+i29Ae79hTbhoGlqPrmAjDBwd eduardo@farinati.dev";
in
{
  "skylab-password.age".publicKeys = [ shared recovery ];
}
