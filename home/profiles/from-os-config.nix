{ osConfig, ... }:

{
  myHome.apps = {
    bitwarden = osConfig.mySystem.passwordManager.bitwarden;
    wezterm = osConfig.mySystem.terminal.wezterm;
    moonlight = osConfig.mySystem.streaming.moonlight;
    clipboard = osConfig.mySystem.clipboard.copyq;
  };
}
