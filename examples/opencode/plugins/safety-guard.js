export const SafetyGuard = async ({ $ }) => {
  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool !== "bash") return;
      const cmd = output.args.command;
      if (!cmd) return;

      let blocked = false;
      let reason = "";

      try {
        const r1 = await $`echo '${cmd}' | terraphim-agent hook --hook-type pre-tool-use --with-guard --json 2>/dev/null || echo '{}'`.text();
        const p1 = JSON.parse(r1);
        if (p1.decision === "block") {
          blocked = true;
          reason = p1.reason || "Blocked by terraphim-agent guard";
        }
      } catch (e) {}

      if (!blocked) {
        try {
          const r2 = await $`echo '${cmd}' | dcg --json 2>/dev/null || echo '{}'`.text();
          const p2 = JSON.parse(r2);
          if (p2.decision === "block") {
            blocked = true;
            reason = p2.reason || "Blocked by dcg";
          }
        } catch (e) {}
      }

      if (blocked) {
        try {
          await $`echo '{"command":"'${cmd}'","reason":"'${reason}'","blocked":true}' | terraphim-agent learn hook 2>/dev/null || true`.text();
        } catch (e) {}

        throw new Error(`SAFETY GUARD BLOCKED\n${reason}\n\nCommand: ${cmd}`);
      }
    },
  };
};
