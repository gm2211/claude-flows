use std::collections::BTreeMap;

#[derive(Debug, Clone)]
pub struct NotificationConfig {
    pub enabled: bool,
    pub waiting_icon: String,
    pub completed_icon: String,
    pub spinner_frames: Vec<String>,
    pub spinner_interval_ms: u64,
}

impl Default for NotificationConfig {
    fn default() -> Self {
        Self {
            enabled: true,
            waiting_icon: "⏳".to_string(),
            completed_icon: "✅".to_string(),
            spinner_frames: vec![
                "⠋".to_string(), "⠙".to_string(), "⠹".to_string(), "⠸".to_string(),
                "⠼".to_string(), "⠴".to_string(), "⠦".to_string(), "⠧".to_string(),
                "⠇".to_string(), "⠏".to_string(),
            ],
            spinner_interval_ms: 100,
        }
    }
}

impl NotificationConfig {
    pub fn from_configuration(config: &BTreeMap<String, String>) -> Self {
        let mut result = Self::default();
        if let Some(enabled) = config.get("enabled") {
            result.enabled = enabled == "true";
        }
        if let Some(icon) = config.get("waiting_icon") {
            if icon.chars().count() > 4 {
                eprintln!("zellij-attention: Warning: waiting_icon '{}' is longer than 4 chars", icon);
            }
            result.waiting_icon = icon.clone();
        }
        if let Some(icon) = config.get("completed_icon") {
            if icon.chars().count() > 4 {
                eprintln!("zellij-attention: Warning: completed_icon '{}' is longer than 4 chars", icon);
            }
            result.completed_icon = icon.clone();
        }
        if let Some(frames_str) = config.get("spinner_frames") {
            let frames: Vec<String> = frames_str
                .split(',')
                .map(|s| s.trim().to_string())
                .filter(|s| !s.is_empty())
                .collect();
            if !frames.is_empty() {
                result.spinner_frames = frames;
            }
        }
        if let Some(interval_str) = config.get("spinner_interval") {
            if let Ok(ms) = interval_str.trim().parse::<u64>() {
                result.spinner_interval_ms = ms;
            }
        }
        result
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_config() {
        let config = NotificationConfig::default();
        assert!(config.enabled);
        assert_eq!(config.waiting_icon, "⏳");
        assert_eq!(config.completed_icon, "✅");
        assert_eq!(config.spinner_frames.len(), 10);
        assert_eq!(config.spinner_frames[0], "⠋");
        assert_eq!(config.spinner_interval_ms, 100);
    }

    #[test]
    fn test_from_configuration_empty() {
        let config_map = BTreeMap::new();
        let config = NotificationConfig::from_configuration(&config_map);
        assert!(config.enabled);
        assert_eq!(config.waiting_icon, "⏳");
        assert_eq!(config.spinner_frames.len(), 10);
    }

    #[test]
    fn test_from_configuration_custom() {
        let mut config_map = BTreeMap::new();
        config_map.insert("enabled".to_string(), "true".to_string());
        config_map.insert("waiting_icon".to_string(), "!".to_string());
        config_map.insert("completed_icon".to_string(), "*".to_string());
        let config = NotificationConfig::from_configuration(&config_map);
        assert!(config.enabled);
        assert_eq!(config.waiting_icon, "!");
        assert_eq!(config.completed_icon, "*");
    }

    #[test]
    fn test_from_configuration_disabled() {
        let mut config_map = BTreeMap::new();
        config_map.insert("enabled".to_string(), "false".to_string());
        let config = NotificationConfig::from_configuration(&config_map);
        assert!(!config.enabled);
    }

    #[test]
    fn test_from_configuration_custom_spinner_frames() {
        let mut config_map = BTreeMap::new();
        config_map.insert("spinner_frames".to_string(), "-,\\,|,/".to_string());
        let config = NotificationConfig::from_configuration(&config_map);
        assert_eq!(config.spinner_frames, vec!["-", "\\", "|", "/"]);
    }

    #[test]
    fn test_from_configuration_spinner_interval() {
        let mut config_map = BTreeMap::new();
        config_map.insert("spinner_interval".to_string(), "200".to_string());
        let config = NotificationConfig::from_configuration(&config_map);
        assert_eq!(config.spinner_interval_ms, 200);
    }

    #[test]
    fn test_from_configuration_empty_spinner_frames_ignored() {
        let mut config_map = BTreeMap::new();
        config_map.insert("spinner_frames".to_string(), "".to_string());
        let config = NotificationConfig::from_configuration(&config_map);
        // Empty string should not replace the default frames
        assert_eq!(config.spinner_frames.len(), 10);
    }
}
