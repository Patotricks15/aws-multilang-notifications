"""Generate docs/architecture.drawio for the Multi-language notification system demo.

Mirrors the AWS Cloud Quest reference layout: Support App -> API entry point ->
dispatcher Lambda -> AWS Step Functions workflow (translate + sentiment analysis
running in parallel, merged and sent) -> Amazon Pinpoint (SMS/Voice) -> Users.
"""

import os

import drawpyo

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "..", "docs")

AWS4_BASE = (
    "sketch=0;outlineConnect=0;fontColor=#232F3E;gradientColor=none;"
    "strokeColor=none;dashed=0;verticalLabelPosition=bottom;verticalAlign=top;"
    "align=center;html=1;fontSize=11;fontStyle=0;aspect=fixed;pointerEvents=1;"
)

GROUP_BASE = (
    "sketch=0;outlineConnect=0;gradientColor=none;html=1;whiteSpace=wrap;fontSize=12;"
    "fontStyle=0;pointerEvents=0;collapsible=0;recursiveResize=0;"
)

CIRCLE_STYLE = (
    "ellipse;whiteSpace=wrap;html=1;fillColor=#232F3D;strokeColor=none;"
    "fontColor=#FFFFFF;fontSize=10;fontStyle=1;"
)


def aws_style(icon_name, fill_color):
    return f"{AWS4_BASE}fillColor={fill_color};shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.{icon_name};"


def add_node(page, name, x, y, icon_name, fill_color, width=64, height=64, parent=None):
    kwargs = {"page": page, "value": name}
    if parent is not None:
        kwargs["parent"] = parent
        kwargs["position_rel_to_parent"] = (x, y)
    else:
        kwargs["position"] = (x, y)
    node = drawpyo.diagram.Object(**kwargs)
    node.width = width
    node.height = height
    node.apply_style_string(aws_style(icon_name, fill_color))
    return node


def add_circle(page, name, x, y, size=30, parent=None):
    kwargs = {"page": page, "value": name}
    if parent is not None:
        kwargs["parent"] = parent
        kwargs["position_rel_to_parent"] = (x, y)
    else:
        kwargs["position"] = (x, y)
    node = drawpyo.diagram.Object(**kwargs)
    node.width = size
    node.height = size
    node.apply_style_string(CIRCLE_STYLE)
    return node


def add_group(page, name, x, y, width, height, stroke_color, gr_icon=None, dashed=True, centered=False):
    group = drawpyo.diagram.Object(page=page, value=name, position=(x, y))
    group.width = width
    group.height = height
    shape_name = "groupCenter" if centered else "group"
    icon_part = f"grIcon=mxgraph.aws4.{gr_icon};" if gr_icon else ""
    stroke_part = "grStroke=1;" if centered else ""
    align = "center" if centered else "left"
    spacing = "" if centered else "spacingLeft=30;"
    style = (
        f"{GROUP_BASE}shape=mxgraph.aws4.{shape_name};{icon_part}{stroke_part}"
        f"strokeColor={stroke_color};fillColor=none;verticalAlign=top;align={align};{spacing}"
        f"fontColor={stroke_color};dashed={1 if dashed else 0};spacingTop=25;"
    )
    group.apply_style_string(style)
    return group


def add_edge(page, source, target, label=None):
    edge = drawpyo.diagram.Edge(page=page, source=source, target=target, label=label)
    edge.waypoints = "orthogonal"
    edge.endArrow = "block"
    edge.startArrow = "none"
    edge.strokeColor = "#545B64"
    return edge


def build_diagram():
    file = drawpyo.File()
    file.file_name = "architecture.drawio"
    file.file_path = OUTPUT_DIR

    page = drawpyo.Page(file=file)
    page.name = "Multi-language notification system"

    support_app = add_node(page, "Support App", 20, 220, "support", "#C925D1")
    api_entry = add_node(page, "Notifications\nAPI", 180, 220, "api_gateway", "#E7157B")
    dispatch_lambda = add_node(page, "Dispatch\n(Lambda)", 340, 220, "lambda_function", "#ED7100")
    sfn_icon = add_node(page, "Step\nFunctions", 500, 220, "step_functions", "#E7157B")

    workflow = add_group(
        page,
        "AWS Step Functions Workflow",
        640,
        60,
        520,
        360,
        "#CD2264",
        gr_icon=None,
        dashed=False,
    )

    start_circle = add_circle(page, "Start", 20, 165, parent=workflow)
    sentiment = add_node(page, "Analyze\nSentiment", 140, 40, "comprehend", "#01A88D", parent=workflow)
    translate = add_node(page, "Translate\nNotification", 140, 260, "translate", "#01A88D", parent=workflow)
    send_lambda = add_node(page, "Send\nNotification\n(Lambda)", 320, 148, "lambda_function", "#ED7100", parent=workflow)
    end_circle = add_circle(page, "End", 460, 165, parent=workflow)

    pinpoint = add_node(page, "Pinpoint", 1240, 220, "pinpoint", "#3334B9")
    users = add_node(page, "Users", 1400, 220, "users", "#232F3D")

    add_edge(page, support_app, api_entry, label="Notifications")
    add_edge(page, api_entry, dispatch_lambda)
    add_edge(page, dispatch_lambda, sfn_icon)
    add_edge(page, sfn_icon, workflow)

    add_edge(page, start_circle, sentiment)
    add_edge(page, start_circle, translate)
    add_edge(page, sentiment, send_lambda)
    add_edge(page, translate, send_lambda, label="Translated notifications\nand user details")
    add_edge(page, send_lambda, end_circle)

    add_edge(page, workflow, pinpoint, label="SMS, Voice Notifications")
    add_edge(page, pinpoint, users)

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    file.write()
    print(f"Wrote {os.path.join(OUTPUT_DIR, file.file_name)}")


if __name__ == "__main__":
    build_diagram()
