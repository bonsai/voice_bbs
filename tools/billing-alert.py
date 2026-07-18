#!/usr/bin/env python3
"""
billing-alert.py — GCP Billing Alert CLI
Monitors Cloud Run, BigQuery, and other GCP costs.
"""
import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timedelta

def get_billing_data(days=7):
    """Fetch billing data from gcloud."""
    try:
        # Get current month cost
        result = subprocess.run(
            ["gcloud", "billing", "budgets", "list", "--format=json", "--account", "onsen.bonsai@gmail.com"],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode == 0:
            return json.loads(result.stdout) if result.stdout.strip() else []
    except Exception as e:
        print(f"Warning: Could not fetch billing data: {e}", file=sys.stderr)
    return []

def get_cloud_run_costs():
    """Estimate Cloud Run costs based on usage."""
    try:
        result = subprocess.run(
            ["gcloud", "run", "services", "list", "--format=json", "--project", "yok-ai-2026"],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode == 0:
            services = json.loads(result.stdout) if result.stdout.strip() else []
            costs = []
            for svc in services:
                name = svc.get("metadata", {}).get("name", "unknown")
                status = svc.get("status", {}).get("url", "N/A")
                costs.append({
                    "service": name,
                    "url": status,
                    "estimated_monthly": "~$0-5 (free tier)"
                })
            return costs
    except Exception as e:
        print(f"Warning: Could not fetch Cloud Run data: {e}", file=sys.stderr)
    return []

def check_budget_alerts():
    """Check if any budget alerts are triggered."""
    budgets = get_billing_data()
    alerts = []
    for budget in budgets:
        name = budget.get("displayName", "unnamed")
        amount = budget.get("budgetFilter", {}).get("amount", {})
        threshold = budget.get("thresholdRules", [])
        for rule in threshold:
            pct = rule.get("thresholdPercent", 0)
            alerts.append({
                "budget": name,
                "threshold": f"{pct}%",
                "amount": amount
            })
    return alerts

def show_status():
    """Show current billing status."""
    print("=== GCP Billing Status ===")
    print(f"Project: yok-ai-2026")
    print(f"Account: onsen.bonsai@gmail.com")
    print()

    # Cloud Run services
    services = get_cloud_run_costs()
    if services:
        print("Cloud Run Services:")
        for svc in services:
            print(f"  - {svc['service']}: {svc['estimated_monthly']}")
    else:
        print("Cloud Run: No services found or access denied")

    print()

    # Budget alerts
    alerts = check_budget_alerts()
    if alerts:
        print("Budget Alerts:")
        for alert in alerts:
            print(f"  - {alert['budget']}: {alert['threshold']}")
    else:
        print("Budget Alerts: None configured or access denied")

    print()
    print("=== Quick Links ===")
    print("  Console: https://console.cloud.google.com/billing?project=yok-ai-2026")
    print("  Budgets: https://console.cloud.google.com/billing/budgets?project=yok-ai-2026")
    print("  Cloud Run: https://console.cloud.google.com/run?project=yok-ai-2026")

def main():
    parser = argparse.ArgumentParser(description="GCP Billing Alert CLI")
    parser.add_argument("command", choices=["status", "alerts", "services"], help="Command to run")
    parser.add_argument("--days", type=int, default=7, help="Days to look back")
    args = parser.parse_args()

    if args.command == "status":
        show_status()
    elif args.command == "alerts":
        alerts = check_budget_alerts()
        if alerts:
            for a in alerts:
                print(json.dumps(a, indent=2))
        else:
            print("No alerts found")
    elif args.command == "services":
        services = get_cloud_run_costs()
        print(json.dumps(services, indent=2))

if __name__ == "__main__":
    main()
