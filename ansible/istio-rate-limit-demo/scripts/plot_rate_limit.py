#!/usr/bin/env python3
import argparse
import csv
import sys
from pathlib import Path

try:
    import plotly.graph_objects as go
except ImportError as exc:
    raise SystemExit(
        "Plotly is required for plotting. Install it with 'pip install plotly'."
    ) from exc


def load_time_series(path: Path) -> tuple[list[float], list[float], str]:
    """Return (times, values, column_name) extracted from a time series CSV."""
    if not path.exists():
        raise FileNotFoundError(f"Missing time series CSV: {path}")
    with path.open(newline="") as handle:
        reader = csv.DictReader(handle)
        fieldnames = reader.fieldnames or []
        if len(fieldnames) < 2:
            raise ValueError(f"CSV {path} must have at least two columns (time,value)")
        time_field = fieldnames[0]
        value_field = fieldnames[1]
        times: list[float] = []
        values: list[float] = []
        for row in reader:
            if not row[time_field]:
                continue
            times.append(float(row[time_field]))
            values.append(float(row[value_field]))
    return times, values, value_field


def load_markers(path: Path) -> dict[str, float]:
    """Return mapping of marker label to timestamp from the markers CSV."""
    markers: dict[str, float] = {}
    if not path.exists():
        return markers
    with path.open(newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            label = row.get("label")
            time_value = row.get("time")
            if not label or time_value in (None, ""):
                continue
            try:
                markers[label] = float(time_value)
            except ValueError:
                continue
    return markers


def figure_with_markers(
    success_csv: Path,
    limited_csv: Path,
    marker_csv: Path,
    output_path: Path,
    title: str,
    marker_labels: dict[str, str],
) -> None:
    success_times, success_values, success_field = load_time_series(success_csv)
    limited_times, limited_values, limited_field = load_time_series(limited_csv)
    # Markers capture notable instants (enable, effective, disable) so we can draw
    # vertical lines and annotations on the chart.
    markers = load_markers(marker_csv)

    fig = go.Figure()

    fig.add_trace(
        go.Line(
            x=success_times,
            y=success_values,
            mode="lines",
            name=f"HTTP 200 ({success_field})",
            line=dict(color="#1f77b4", width=2),
        )
    )

    fig.add_trace(
        go.Scatter(
            x=limited_times,
            y=limited_values,
            mode="lines",
            name=f"HTTP 429 ({limited_field})",
            line=dict(color="#d62728", width=2, dash="dash"),
        )
    )

    all_times = success_times + limited_times
    max_y = max(success_values + limited_values + [0.0])
    annotation_y = max_y * 1.05 if max_y > 0 else 1

    marker_tick_values: set[float] = set()

    # Distinguish each marker visually so the operator can instantly recognize the
    # key phases of the demonstration.
    marker_styles: dict[str, dict[str, str]] = {
        "rate_limit_enabled": {"color": "#2ca02c"},  # green
        "rate_limit_effective": {"color": "#ff7f0e"},  # orange
        "rate_limit_disabled": {"color": "#d62728"},  # red
    }

    for idx, (marker_key, marker_label) in enumerate(marker_labels.items()):
        marker_time = markers.get(marker_key)
        if marker_time is None:
            continue
        marker_tick_values.add(marker_time)
        marker_color = marker_styles.get(marker_key, {}).get("color", "#555555")
        # Alternate annotation direction so multiple labels do not overlap.
        horizontal_offset = -80 if idx % 2 == 0 else 80
        fig.add_vline(
            x=marker_time,
            line_width=2,
            line_dash="dot",
            line_color=marker_color,
        )
        fig.add_annotation(
            x=marker_time,
            y=annotation_y,
            text=marker_label,
            showarrow=True,
            arrowhead=2,
            arrowsize=1,
            arrowcolor=marker_color,
            ax=horizontal_offset,
            ay=-60,
            xanchor="left" if horizontal_offset >= 0 else "right",
        )

    max_time = max(all_times) if all_times else 0
    min_time = min(all_times) if all_times else 0
    range_span = max_time - min_time
    base_tick = 1
    if range_span > 0:
        # Aim for roughly a dozen ticks on the x-axis while keeping marker ticks.
        base_tick = max(1, round(range_span / 12))

    regular_ticks = list(range(int(min_time), int(max_time) + base_tick, base_tick))
    combined_ticks = sorted({*regular_ticks, *marker_tick_values})

    fig.update_layout(
        title=title,
        xaxis_title="Time (s)",
        yaxis_title="Throughput (ops/s)",
        template="plotly_white",
        hovermode="x unified",
    )

    fig.update_xaxes(
        tickmode="array",
        tickvals=combined_ticks,
        ticktext=[str(int(val)) if float(val).is_integer() else f"{val:.2f}" for val in combined_ticks],
        tickangle=90,
    )

    fig.update_yaxes(rangemode="tozero")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.write_html(output_path, include_plotlyjs="cdn", full_html=True)


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Collect CLI arguments describing the input/output artifact paths."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--success-csv", required=True, type=Path)
    parser.add_argument("--limited-csv", required=True, type=Path)
    parser.add_argument("--markers-csv", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument(
        "--title",
        default="Istio Rate Limit Demo",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> None:
    """Drive the plotting workflow based on user-supplied arguments."""
    args = parse_args(argv)
    marker_labels = {
        "rate_limit_enabled": "Rate limit enabled",
        "rate_limit_effective": "Rate limit effective",
        "rate_limit_disabled": "Rate limit disabled",
    }
    figure_with_markers(
        success_csv=args.success_csv,
        limited_csv=args.limited_csv,
        marker_csv=args.markers_csv,
        output_path=args.output,
        title=args.title,
        marker_labels=marker_labels,
    )


if __name__ == "__main__":
    main(sys.argv[1:])
