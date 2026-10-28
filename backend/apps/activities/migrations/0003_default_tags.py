from django.db import migrations

# 처음 넣어 두는 분야 태그. 이후에는 Admin에서 더하거나 고친다.
DEFAULT_TAGS = ("web", "pwn", "reversing", "forensics", "crypto", "iot", "network", "ai")


def add_default_tags(apps, schema_editor):
    Tag = apps.get_model("activities", "Tag")
    for name in DEFAULT_TAGS:
        Tag.objects.get_or_create(name=name)


class Migration(migrations.Migration):

    dependencies = [
        ("activities", "0002_activity_archive"),
    ]

    operations = [
        migrations.RunPython(add_default_tags, migrations.RunPython.noop),
    ]
