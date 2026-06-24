import { getWeightHistory } from "@/lib/history";
import { EmptyState } from "../page";
import { TrendsView } from "./trends-view";

export default async function TrendsPage() {
  const series = await getWeightHistory();

  if (series.length === 0) {
    return (
      <EmptyState>
        No logged weights yet. Log weight on a few sets and complete a workout to
        see trends here.
      </EmptyState>
    );
  }

  return <TrendsView series={series} />;
}
