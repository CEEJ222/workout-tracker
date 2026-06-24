"use client";

import { useState } from "react";
import type { WeightSeries } from "@/lib/history";
import { WeightChart } from "../weight-chart";

export function TrendsView({ series }: { series: WeightSeries[] }) {
  const [selectedId, setSelectedId] = useState(series[0]?.exerciseId ?? "");
  const current = series.find((s) => s.exerciseId === selectedId) ?? series[0];

  return (
    <div className="flex flex-col gap-3">
      <select
        value={selectedId}
        onChange={(e) => setSelectedId(e.target.value)}
        className="w-full rounded-lg border border-line bg-card px-3 py-2.5 text-[15px] text-ink"
      >
        {series.map((s) => (
          <option key={s.exerciseId} value={s.exerciseId}>
            {s.exerciseName}
          </option>
        ))}
      </select>

      <div className="rounded-card border border-line bg-card px-3 py-4">
        <div className="mb-1 px-1 text-[13px] font-semibold text-ink">
          {current.exerciseName}
        </div>
        <div className="mb-3 px-1 text-[12px] text-ink-2">
          {current.points.length} session
          {current.points.length > 1 ? "s" : ""} · latest{" "}
          {current.points[current.points.length - 1].weight} lb
        </div>
        <WeightChart points={current.points} />
      </div>
    </div>
  );
}
