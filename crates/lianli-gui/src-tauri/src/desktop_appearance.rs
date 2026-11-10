use gio::glib::{ToVariant, Variant, VariantTy};
use gio::DBusConnection;
use serde::Serialize;
use tauri::{AppHandle, Emitter};

pub const CHANGED_EVENT: &str = "desktop-appearance-changed";

const PORTAL_NAME: &str = "org.freedesktop.portal.Desktop";
const PORTAL_PATH: &str = "/org/freedesktop/portal/desktop";
const SETTINGS_INTERFACE: &str = "org.freedesktop.portal.Settings";
const APPEARANCE_NAMESPACE: &str = "org.freedesktop.appearance";
const ACCENT_KEY: &str = "accent-color";
const COLOR_SCHEME_KEY: &str = "color-scheme";
const READ_TIMEOUT_MS: i32 = 2_000;

#[derive(Clone, Debug, Default, PartialEq, Serialize)]
pub struct DesktopAppearance {
    accent: Option<String>,
    color_scheme: Option<&'static str>,
}

#[derive(Clone, Debug, PartialEq, Serialize)]
#[serde(tag = "key", content = "value", rename_all = "snake_case")]
pub enum AppearanceChange {
    Accent(Option<String>),
    ColorScheme(Option<&'static str>),
}

#[tauri::command]
pub async fn desktop_appearance() -> DesktopAppearance {
    tauri::async_runtime::spawn_blocking(read)
        .await
        .unwrap_or_default()
}

fn read() -> DesktopAppearance {
    let bus = match gio::bus_get_sync(gio::BusType::Session, gio::Cancellable::NONE) {
        Ok(bus) => bus,
        Err(error) => {
            tracing::debug!("Desktop appearance unavailable: no session bus: {error}");
            return DesktopAppearance::default();
        }
    };
    DesktopAppearance {
        accent: read_setting(&bus, ACCENT_KEY)
            .as_ref()
            .and_then(accent_from),
        color_scheme: read_setting(&bus, COLOR_SCHEME_KEY)
            .as_ref()
            .and_then(color_scheme_from),
    }
}

/// Subscribes on the calling thread's main context, so call it from the GTK main thread.
pub fn watch(app: AppHandle) {
    let bus = match gio::bus_get_sync(gio::BusType::Session, gio::Cancellable::NONE) {
        Ok(bus) => bus,
        Err(error) => {
            tracing::debug!("Desktop appearance changes unavailable: no session bus: {error}");
            return;
        }
    };
    // The shared session bus outlives this handle, so the subscription lasts for the process.
    bus.signal_subscribe(
        Some(PORTAL_NAME),
        Some(SETTINGS_INTERFACE),
        Some("SettingChanged"),
        Some(PORTAL_PATH),
        Some(APPEARANCE_NAMESPACE),
        gio::DBusSignalFlags::NONE,
        move |_, _, _, _, _, params| {
            let Some(change) = change_from(params) else {
                return;
            };
            if let Err(error) = app.emit(CHANGED_EVENT, change) {
                tracing::debug!("Cannot forward desktop appearance change: {error}");
            }
        },
    );
}

fn read_setting(bus: &DBusConnection, key: &str) -> Option<Variant> {
    // Read is the deprecated predecessor of ReadOne and still the only method on older portals.
    for method in ["ReadOne", "Read"] {
        match bus.call_sync(
            Some(PORTAL_NAME),
            PORTAL_PATH,
            SETTINGS_INTERFACE,
            method,
            Some(&(APPEARANCE_NAMESPACE, key).to_variant()),
            None,
            gio::DBusCallFlags::NONE,
            READ_TIMEOUT_MS,
            gio::Cancellable::NONE,
        ) {
            Ok(reply) => return Some(unwrap_variant(reply.child_value(0))),
            Err(error) => tracing::debug!("Portal {method} {key} failed: {error}"),
        }
    }
    None
}

fn unwrap_variant(mut value: Variant) -> Variant {
    while value.is_type(VariantTy::VARIANT) {
        match value.as_variant() {
            Some(inner) => value = inner,
            None => break,
        }
    }
    value
}

fn change_from(params: &Variant) -> Option<AppearanceChange> {
    let (namespace, key, value) = params.get::<(String, String, Variant)>()?;
    if namespace != APPEARANCE_NAMESPACE {
        return None;
    }
    let value = unwrap_variant(value);
    match key.as_str() {
        ACCENT_KEY => Some(AppearanceChange::Accent(accent_from(&value))),
        COLOR_SCHEME_KEY => Some(AppearanceChange::ColorScheme(color_scheme_from(&value))),
        _ => None,
    }
}

fn accent_from(value: &Variant) -> Option<String> {
    let (red, green, blue) = value.get::<(f64, f64, f64)>()?;
    accent_hex(red, green, blue)
}

/// The portal reports components in 0..=1; anything outside that range means no accent is set.
fn accent_hex(red: f64, green: f64, blue: f64) -> Option<String> {
    let channel = |component: f64| {
        (0.0..=1.0)
            .contains(&component)
            .then(|| (component * 255.0).round() as u8)
    };
    Some(format!(
        "#{:02x}{:02x}{:02x}",
        channel(red)?,
        channel(green)?,
        channel(blue)?
    ))
}

fn color_scheme_from(value: &Variant) -> Option<&'static str> {
    match value.get::<u32>()? {
        1 => Some("dark"),
        2 => Some("light"),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accent_hex_converts_portal_components() {
        assert_eq!(accent_hex(0.2, 0.5, 0.9).as_deref(), Some("#3380e6"));
        assert_eq!(accent_hex(0.0, 0.0, 1.0).as_deref(), Some("#0000ff"));
    }

    #[test]
    fn accent_hex_rejects_unset_accent() {
        assert_eq!(accent_hex(-1.0, -1.0, -1.0), None);
        assert_eq!(accent_hex(0.5, 1.2, 0.5), None);
        assert_eq!(accent_hex(f64::NAN, 0.5, 0.5), None);
    }

    #[test]
    fn color_scheme_maps_portal_values() {
        assert_eq!(color_scheme_from(&1u32.to_variant()), Some("dark"));
        assert_eq!(color_scheme_from(&2u32.to_variant()), Some("light"));
        assert_eq!(color_scheme_from(&0u32.to_variant()), None);
    }

    #[test]
    fn setting_changed_signal_yields_accent_change() {
        let params = (
            APPEARANCE_NAMESPACE,
            ACCENT_KEY,
            (0.2f64, 0.5f64, 0.9f64).to_variant(),
        )
            .to_variant();
        assert_eq!(params.type_().as_str(), "(ssv)");
        assert_eq!(
            change_from(&params),
            Some(AppearanceChange::Accent(Some("#3380e6".into())))
        );
    }

    #[test]
    fn setting_changed_signal_ignores_other_namespaces() {
        let params = (
            "org.gnome.desktop.interface",
            ACCENT_KEY,
            (0.2f64, 0.5f64, 0.9f64).to_variant(),
        )
            .to_variant();
        assert_eq!(change_from(&params), None);
    }

    #[test]
    fn appearance_change_serializes_for_frontend() {
        let json = serde_json::to_value(AppearanceChange::ColorScheme(Some("dark"))).unwrap();
        assert_eq!(
            json,
            serde_json::json!({ "key": "color_scheme", "value": "dark" })
        );
    }
}
