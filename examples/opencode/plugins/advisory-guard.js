export const AdvisoryGuard = async ({ $ }) => {
  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool !== "bash") return;
      const cmd = output.args.command;
      if (!cmd) return;

      try {
        const r1 = await $`echo '${cmd}' | terraphim-agent hook --hook-type pre-tool-use --with-guard --json 2>/dev/null || echo '{}'`.text();
        const p1 = JSON.parse(r1);
        if (p1.decision === "block") {
          console.warn(`ADVISORY: ${p1.reason || "Destructive command detected"}`);
        }
      } catch (e) {}

      try {
        const r2 = await $`echo '${cmd}' | dcg --json 2>/dev/null || echo '{}'`.text();
        const p2 = JSON.parse(r2);
        if (p2.decision === "block") {
          console.warn(`ADVISORY (dcg): ${p2.reason || "Destructive command detected"}`);
        }
      } catch (e) {}
    },
  };
};
