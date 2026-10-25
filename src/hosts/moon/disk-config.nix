{ ... }:

{
  disko.devices.disk.moon = {
    type = "disk";
    # KIOXIA 128 GB NVMe.
    device = "/dev/disk/by-id/nvme-eui.01000000000000008ce38e0403d48bea";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          label = "efi";
          content = {
            type = "filesystem";
            format = "vfat";
            extraArgs = [ "-n" "efi" ];
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          label = "nixos";
          content = {
            type = "filesystem";
            format = "ext4";
            extraArgs = [ "-L" "nixos" ];
            mountpoint = "/";
          };
        };
      };
    };
  };
}
