from django.contrib import admin

from .models import (
    User,
    Movie,
    Review,
    Like,
)

# Register your models here.
admin.site.register(User)


@admin.register(Movie)
class MovieAdmin(admin.ModelAdmin):
    list_display = ['id', 'title', 'release_year', 'created_at']
    search_fields = ['title']


@admin.register(Review)
class ReviewAdmin(admin.ModelAdmin):
    list_display = ['id', 'movie', 'user', 'rating', 'created_at']


@admin.register(Like)
class LikeAdmin(admin.ModelAdmin):
    list_display = ['id', 'movie', 'user', 'created_at']
