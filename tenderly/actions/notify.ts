type AlertEvent = {
    transaction?: {
        hash?: string;
        from?: string;
        to?: string;
        network?: string | number;
    };
    alert?: {
        id?: string;
        name?: string;
    };
};

async function postToSlack(title: string, event: AlertEvent) {
    const webhookUrl = process.env.SLACK_WEBHOOK_URL;
    if (!webhookUrl) {
        console.log("SLACK_WEBHOOK_URL is not configured; event payload follows.");
        console.log(JSON.stringify(event, null, 2));
        return;
    }

    const tx = event.transaction ?? {};
    const alert = event.alert ?? {};
    const response = await fetch(webhookUrl, {
        method: "POST",
        headers: {"content-type": "application/json"},
        body: JSON.stringify({
            text: [
                `Tenderly alert: ${title}`,
                `Alert: ${alert.name ?? alert.id ?? "unknown"}`,
                `Tx: ${tx.hash ?? "unknown"}`,
                `From: ${tx.from ?? "unknown"}`,
                `To: ${tx.to ?? "unknown"}`,
                `Network: ${tx.network ?? "unknown"}`,
            ].join("\n"),
        }),
    });

    if (!response.ok) {
        throw new Error(`Slack webhook failed with status ${response.status}`);
    }
}

export async function largeBalanceChange(_: unknown, event: AlertEvent) {
    await postToSlack("large balance change", event);
}

export async function privilegedCall(_: unknown, event: AlertEvent) {
    await postToSlack("privileged function call", event);
}

export async function failedTransaction(_: unknown, event: AlertEvent) {
    await postToSlack("failed transaction", event);
}
