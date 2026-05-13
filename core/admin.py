from django.contrib import admin

from .models import (
    User,
    Movie,
)

# Register your models here.
admin.site.register(User)

@admin.register(Movie)
class MovieAdmin(admin.ModelAdmin):
    list_display = ['id', 'title', 'release_year', 'created_at']
    search_fields = ['title']
