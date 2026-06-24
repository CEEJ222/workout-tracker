type Point = { date: string; weight: number };

/**
 * Minimal dependency-free line+point chart for a single exercise's logged
 * weight over time. Pure SVG, sized to the mobile column.
 */
export function WeightChart({ points }: { points: Point[] }) {
  const width = 340;
  const height = 180;
  const padL = 34;
  const padR = 12;
  const padT = 14;
  const padB = 26;

  const weights = points.map((p) => p.weight);
  const minW = Math.min(...weights);
  const maxW = Math.max(...weights);
  // Pad the y-range so a flat line doesn't sit on the axis.
  const span = maxW - minW || Math.max(maxW * 0.1, 5);
  const yMin = minW - span * 0.2;
  const yMax = maxW + span * 0.2;

  const innerW = width - padL - padR;
  const innerH = height - padT - padB;

  const x = (i: number) =>
    padL + (points.length === 1 ? innerW / 2 : (i / (points.length - 1)) * innerW);
  const y = (w: number) =>
    padT + innerH - ((w - yMin) / (yMax - yMin)) * innerH;

  const line = points.map((p, i) => `${x(i)},${y(p.weight)}`).join(" ");

  return (
    <svg
      viewBox={`0 0 ${width} ${height}`}
      className="w-full"
      role="img"
      aria-label="Weight over time"
    >
      {/* y-axis guide labels (max / min) */}
      {[maxW, minW].map((w) => (
        <g key={w}>
          <line
            x1={padL}
            x2={width - padR}
            y1={y(w)}
            y2={y(w)}
            stroke="var(--color-line-2)"
            strokeWidth={1}
          />
          <text
            x={padL - 6}
            y={y(w) + 3}
            textAnchor="end"
            fontSize={10}
            fill="var(--color-ink-3)"
          >
            {w}
          </text>
        </g>
      ))}

      {points.length > 1 && (
        <polyline
          points={line}
          fill="none"
          stroke="var(--color-ink)"
          strokeWidth={2}
          strokeLinejoin="round"
          strokeLinecap="round"
        />
      )}

      {points.map((p, i) => (
        <circle
          key={i}
          cx={x(i)}
          cy={y(p.weight)}
          r={3.5}
          fill="var(--color-card)"
          stroke="var(--color-ink)"
          strokeWidth={2}
        />
      ))}

      {/* x-axis: first and last date */}
      <text x={padL} y={height - 8} fontSize={10} fill="var(--color-ink-3)">
        {shortDate(points[0].date)}
      </text>
      {points.length > 1 && (
        <text
          x={width - padR}
          y={height - 8}
          textAnchor="end"
          fontSize={10}
          fill="var(--color-ink-3)"
        >
          {shortDate(points[points.length - 1].date)}
        </text>
      )}
    </svg>
  );
}

function shortDate(iso: string): string {
  return new Date(iso).toLocaleDateString(undefined, {
    month: "short",
    day: "numeric",
  });
}
