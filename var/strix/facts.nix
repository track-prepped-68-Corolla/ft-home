{
  hostname    = "strix";
  arch        = "x86_64-linux";
  primaryUser = "joe";
  gpu = {
    vendor      = "amd";
    hasDiscrete = false;
    hasNvidia   = false;
    hasAmd      = true;
  };
}
