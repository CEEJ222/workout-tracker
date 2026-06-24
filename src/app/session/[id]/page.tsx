import { notFound } from "next/navigation";
import { requireUser } from "@/lib/auth/session";
import { getSessionDetail } from "@/lib/session-detail";
import { SessionView } from "./session-view";

export default async function SessionPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  await requireUser();
  const { id } = await params;
  const detail = await getSessionDetail(id);
  if (!detail) notFound();

  return <SessionView detail={detail} />;
}
