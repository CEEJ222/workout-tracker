import { setTheme } from "@/app/actions/settings";
import type { ThemePreference } from "@/lib/queries";

const OPTIONS: { value: ThemePreference; label: string }[] = [
  { value: "system", label: "Auto" },
  { value: "light", label: "Light" },
  { value: "dark", label: "Dark" },
];

/**
 * Three-state theme control.
 *
 * Three states, not a switch: a two-position toggle can express light and dark
 * but has nowhere to put "follow my device" — so once you touched it you could
 * never get back to the default. 'Auto' is a first-class option here for that
 * reason, and it is the one that ships on by default.
 *
 * Plain forms posting a server action, so this works without client JS and
 * needs no state: the current value comes from the server, and the page
 * re-renders with the new palette already applied.
 */
export function ThemeToggle({ current }: { current: ThemePreference }) {
  return (
    <div
      role="group"
      aria-label="Theme"
      className="flex items-center gap-px overflow-hidden rounded-lg border border-line bg-field"
    >
      {OPTIONS.map((opt) => {
        const active = opt.value === current;
        return (
          <form key={opt.value} action={setTheme}>
            <input type="hidden" name="theme" value={opt.value} />
            <button
              type="submit"
              aria-pressed={active}
              title={`Theme: ${opt.label}`}
              className={`flex h-[26px] w-[30px] items-center justify-center text-[11px] ${
                active ? "bg-ink text-on-ink" : "text-ink-2 active:bg-line-2"
              }`}
            >
              <Icon kind={opt.value} />
              <span className="sr-only">{opt.label}</span>
            </button>
          </form>
        );
      })}
    </div>
  );
}

function Icon({ kind }: { kind: ThemePreference }) {
  const common = {
    viewBox: "0 0 16 16",
    className: "h-[13px] w-[13px]",
    "aria-hidden": true as const,
    fill: "none",
    stroke: "currentColor",
    strokeWidth: 1.5,
    strokeLinecap: "round" as const,
    strokeLinejoin: "round" as const,
  };

  if (kind === "light") {
    return (
      <svg {...common}>
        <circle cx="8" cy="8" r="3" />
        <path d="M8 1.5v1.2M8 13.3v1.2M14.5 8h-1.2M2.7 8H1.5M12.6 3.4l-.85.85M4.25 11.75l-.85.85M12.6 12.6l-.85-.85M4.25 4.25l-.85-.85" />
      </svg>
    );
  }
  if (kind === "dark") {
    return (
      <svg {...common}>
        <path d="M13.5 9.6A5.8 5.8 0 0 1 6.4 2.5a5.8 5.8 0 1 0 7.1 7.1Z" />
      </svg>
    );
  }
  // Auto: half-filled circle — the device decides which half you get.
  return (
    <svg {...common}>
      <circle cx="8" cy="8" r="5.2" />
      <path d="M8 2.8a5.2 5.2 0 0 1 0 10.4Z" fill="currentColor" stroke="none" />
    </svg>
  );
}
