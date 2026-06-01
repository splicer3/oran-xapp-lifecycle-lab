#!/usr/bin/env python3
import argparse
import csv
import datetime as dt
import json
from pathlib import Path


def parse_time(value):
    """Convert Prometheus or ISO time values to timezone-aware datetimes."""
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return dt.datetime.fromtimestamp(float(value), tz=dt.timezone.utc)
    if isinstance(value, str):
        try:
            numeric = float(value)
            return dt.datetime.fromtimestamp(numeric, tz=dt.timezone.utc)
        except ValueError:
            pass
        normalized = value.replace("Z", "+00:00")
        try:
            parsed = dt.datetime.fromisoformat(normalized)
            if parsed.tzinfo is None:
                parsed = parsed.replace(tzinfo=dt.timezone.utc)
            return parsed
        except ValueError:
            return None
    return None


def mean(values):
    return sum(values) / len(values) if values else 0.0


def load_rows(paths):
    rows = []
    for path in paths:
        with open(path, encoding="utf-8") as handle:
            payload = json.load(handle)
        results = payload.get("data", {}).get("result", [])
        for result in results:
            metric = result.get("metric", {}) or {}
            version = metric.get("destination_version") or metric.get("version") or "unknown"
            samples = result.get("values")
            if not samples and result.get("value"):
                samples = [result["value"]]
            for sample in samples or []:
                if not sample or len(sample) < 2:
                    continue
                timestamp, raw_value = sample
                ts = parse_time(timestamp)
                if ts is None:
                    continue
                rows.append({"time": ts, "version": version, "value": float(raw_value)})
    if not rows:
        raise SystemExit("no data")
    rows.sort(key=lambda row: row["time"])
    return rows


def build_pivot(rows):
    by_time = {}
    versions = set()
    for row in rows:
        ts = row["time"]
        version = row["version"]
        versions.add(version)
        by_time.setdefault(ts, {}).setdefault(version, []).append(row["value"])

    times = sorted(by_time.keys())
    version_list = sorted(versions)
    series = {version: [] for version in version_list}
    for ts in times:
        slot = by_time.get(ts, {})
        for version in version_list:
            series[version].append(mean(slot.get(version, [])))

    return {"times": times, "versions": version_list, "series": series}


def load_flip_events(path):
    events = []
    with open(path, encoding="utf-8") as handle:
        for raw_event in json.load(handle):
            ts = parse_time(raw_event.get("timestamp"))
            if ts is None:
                continue
            events.append(
                {
                    "time": ts,
                    "to_version": raw_event.get("to_version"),
                    "from_version": raw_event.get("from_version"),
                    "action": raw_event.get("action", "apply"),
                }
            )
    return sorted(events, key=lambda event: event["time"])


def compute_effective_events(events, pivot, threshold):
    effective = []
    times = pivot["times"]
    series = pivot["series"]
    for event in events:
        from_version = event.get("from_version")
        if not from_version or from_version not in series:
            continue

        start_index = None
        for idx, ts in enumerate(times):
            if ts >= event["time"]:
                start_index = idx
                break
        if start_index is None:
            continue

        values = series[from_version]
        for idx in range(start_index, len(values)):
            if values[idx] <= threshold:
                effective.append(
                    {
                        "time": times[idx],
                        "to_version": event.get("to_version"),
                        "from_version": from_version,
                        "action": "effective",
                    }
                )
                break
    return effective


def format_utc_iso(ts):
    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=dt.timezone.utc)
    return ts.astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def save_csv(pivot, path):
    out_path = Path(path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["time"] + pivot["versions"])
        for idx, ts in enumerate(pivot["times"]):
            row = [format_utc_iso(ts)]
            for version in pivot["versions"]:
                row.append(pivot["series"][version][idx])
            writer.writerow(row)


def load_pivot_from_csv(path):
    csv_path = Path(path)
    with csv_path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        fieldnames = reader.fieldnames or []
        if len(fieldnames) < 2:
            raise SystemExit(f"CSV '{csv_path}' must contain at least two columns: time + one version column.")
        time_field = fieldnames[0]
        versions = fieldnames[1:]
        times = []
        series = {version: [] for version in versions}
        for row in reader:
            ts = parse_time(row.get(time_field))
            if ts is None:
                continue
            times.append(ts)
            for version in versions:
                raw_value = row.get(version, "0")
                try:
                    value = float(raw_value) if raw_value not in (None, "") else 0.0
                except ValueError:
                    value = 0.0
                series[version].append(value)
    if not times:
        raise SystemExit(f"No valid time points found in '{csv_path}'.")
    return {"times": times, "versions": versions, "series": series}


def render_plotly_html(pivot, applies, output_path, title):
    try:
        import plotly.graph_objects as go
    except ImportError as exc:
        raise SystemExit(
            "Plotly is required for HTML output. Install it with 'pip install plotly'."
        ) from exc

    fig = go.Figure()
    palette = ["#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd"]
    for idx, version in enumerate(pivot["versions"]):
        fig.add_trace(
            go.Scatter(
                x=pivot["times"],
                y=pivot["series"][version],
                mode="lines+markers",
                name=version,
                line=dict(color=palette[idx % len(palette)], width=2),
            )
        )

    max_y = 0.0
    for version in pivot["versions"]:
        max_y = max(max_y, max(pivot["series"][version] or [0.0]))
    annotation_y = max_y * 1.05 if max_y > 0 else 1.0

    version_colors = {}
    for idx, version in enumerate(pivot["versions"]):
        version_colors[version] = palette[idx % len(palette)]

    seen_flip_legend = set()
    for event in applies:
        marker_time = event["time"]
        to_version = event.get("to_version") or "unknown"
        flip_name = f"flip -> {to_version}"
        show_legend = flip_name not in seen_flip_legend
        seen_flip_legend.add(flip_name)
        fig.add_trace(
            go.Scatter(
                x=[marker_time, marker_time],
                y=[0.0, annotation_y],
                mode="lines",
                name=flip_name,
                legendgroup=flip_name,
                showlegend=show_legend,
                line=dict(color=version_colors.get(to_version, "#636363"), width=2, dash="dot"),
                hovertemplate=f"{flip_name}<br>%{{x|%Y-%m-%d %H:%M:%S UTC}}<extra></extra>",
            )
        )

    fig.update_layout(
        title=title,
        xaxis_title="Time (UTC)",
        yaxis_title="Bytes/sec (Prometheus rate)",
        template="plotly_white",
        hovermode="x unified",
    )
    fig.update_yaxes(rangemode="tozero")

    out_path = Path(output_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    fig.write_html(out_path, include_plotlyjs="cdn", full_html=True)


def parse_args():
    parser = argparse.ArgumentParser(description="Process Istio A/B TCP metrics into CSV and Plotly HTML.")
    parser.add_argument("metrics_files", nargs="*", help="Prometheus JSON snapshots from query_range.")
    parser.add_argument(
        "--in-csv",
        dest="in_csv",
        help="Optional existing pivot CSV input (time + version columns). If set, JSON metrics files are not required.",
    )
    parser.add_argument("--flip-events", dest="flip_events", help="Path to flip_events.json")
    parser.add_argument("--out-csv", dest="out_csv", help="Write pivoted metrics to CSV.")
    parser.add_argument("--out-html", dest="out_html", help="Write interactive Plotly chart to HTML.")
    parser.add_argument(
        "--title",
        dest="title",
        default="Istio TCP traffic by version",
        help="Chart title for HTML output.",
    )
    parser.add_argument(
        "--drop-threshold",
        dest="drop_threshold",
        type=float,
        default=1.0,
        help="Value at or below which the old version is considered drained.",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    if args.in_csv:
        pivot = load_pivot_from_csv(args.in_csv)
    else:
        if not args.metrics_files:
            raise SystemExit("Provide at least one metrics JSON file, or use --in-csv <csv_file>.")
        rows = load_rows(args.metrics_files)
        pivot = build_pivot(rows)

    applies = []
    if args.flip_events:
        applies = load_flip_events(args.flip_events)

    if args.out_csv:
        save_csv(pivot, args.out_csv)

    if args.out_html:
        render_plotly_html(pivot, applies, args.out_html, args.title)


if __name__ == "__main__":
    main()
