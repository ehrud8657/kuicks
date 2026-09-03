from django.conf import settings
from django.db import models

class Event(models.Model):
    name = models.CharField(max_length=150)
    date = models.DateField()
    participants = models.ManyToManyField(settings.AUTH_USER_MODEL, through="EventParticipation", related_name="events")
    def __str__(self): return self.name
    class Meta: ordering = ("-date",)

class EventParticipation(models.Model):
    member = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    event = models.ForeignKey(Event, on_delete=models.CASCADE)
    class Meta:
        constraints = [models.UniqueConstraint(fields=("member", "event"), name="unique_event_participation")]

