from django.db import migrations, models


def split_project_names(apps, schema_editor):
    """프로젝트의 '이름'은 팀명, '주제'는 사실상 프로젝트명이었다. 이름=프로젝트명, 팀명=팀명으로 옮긴다.

    주제가 비어 있던 프로젝트는 프로젝트명을 알 수 없어 이름에 팀명이 그대로 남는다(운영진이 고친다).
    """
    Activity = apps.get_model("activities", "Activity")
    for activity in Activity.objects.filter(kind="project"):
        if not activity.team_name:
            activity.team_name = activity.title[:100]
        if activity.topic:
            activity.title = activity.topic[:150]
        activity.save(update_fields=["title", "team_name"])


def join_project_names(apps, schema_editor):
    """되돌리기: 팀명을 다시 이름으로, 이름(프로젝트명)을 주제로."""
    Activity = apps.get_model("activities", "Activity")
    for activity in Activity.objects.filter(kind="project"):
        if activity.title != activity.team_name:
            activity.topic = activity.title[:200]
        if activity.team_name:
            activity.title = activity.team_name
        activity.team_name = ""
        activity.save(update_fields=["title", "topic", "team_name"])


class Migration(migrations.Migration):

    dependencies = [
        ("activities", "0003_default_tags"),
    ]

    operations = [
        migrations.AddField(
            model_name="activity",
            name="mentor",
            field=models.CharField(
                blank=True,
                help_text="프로젝트를 지도하는 교수·선배 등. 여러 명이면 쉼표로 구분합니다.",
                max_length=100,
                verbose_name="멘토",
            ),
        ),
        migrations.AlterField(
            model_name="activity",
            name="team_name",
            field=models.CharField(
                blank=True,
                help_text="프로젝트 팀이 정한 이름, 또는 대회에 나간 팀 이름",
                max_length=100,
                verbose_name="팀명",
            ),
        ),
        migrations.AlterField(
            model_name="activity",
            name="title",
            field=models.CharField(
                help_text="프로젝트는 프로젝트명, 대회·행사는 그 이름을 적습니다.", max_length=150, verbose_name="이름"
            ),
        ),
        # 주제를 지우기 전에 옮긴다.
        migrations.RunPython(split_project_names, join_project_names),
        migrations.RemoveField(
            model_name="activity",
            name="topic",
        ),
    ]
