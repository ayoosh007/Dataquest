from django.core.management.base import BaseCommand
from dataquestapp.models import DashboardData

class Command(BaseCommand):
    help = 'Populate dashboard with sample data'

    def handle(self, *args, **options):
        # Create sample dashboard data
        sample_data = DashboardData.objects.create(
            total_reports=1248,
            pending=89,
            in_progress=156,
            resolved=1002,
            today_reports=27,
            avg_resolution=5,
            top_category='Infrastructure',
            open_reports=245,
            category_data={
                'labels': ['Infrastructure', 'Sanitation', 'Public health', 'Environment', 'Other', 'Parks Housing'],
                'datasets': [{
                    'data': [420, 260, 310, 130, 127, 153],
                    'backgroundColor': ['#7c3aed', '#06b6d4', '#4f46e5', '#10b981', '#f59e0b', '#4f6e45'],
                    'hoverOffset': 10
                }]
            },
            markers=[
                {'lat': 13.0810, 'lng': 80.2680, 'title': 'Pothole on 5th Ave', 'cat': 'Infrastructure'},
                {'lat': 13.0795, 'lng': 80.2705, 'title': 'Broken streetlight', 'cat': 'Infrastructure'},
                {'lat': 13.0823, 'lng': 80.2670, 'title': 'Garbage overflow', 'cat': 'Sanitation'},
                {'lat': 13.0840, 'lng': 80.2710, 'title': 'Fallen branch', 'cat': 'Environment'}
            ]
        )
        
        self.stdout.write(
            self.style.SUCCESS(f'Successfully created dashboard data with ID: {sample_data.id}')
        )
