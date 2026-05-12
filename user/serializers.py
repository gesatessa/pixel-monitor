from django.contrib.auth import get_user_model, authenticate

from django.utils.translation import gettext as _

from rest_framework import serializers


class UserSerializer(serializers.ModelSerializer):
    
    class Meta:
        model = get_user_model()
        # required fields when making a request to create a user
        fields = ['email', 'password']
        # extra validation checks
        # wirte_only: true: do NOT return the value (security)
        # if `min_length` is not satisfied, it sends 400 bad request
        extra_kwargs = {
            'password': {'write_only': True, 'min_length': 8}
        }

    def create(self, validated_data):
        # if the validation works, call `.create_user()` method from the UserManager
        return get_user_model().objects.create_user(**validated_data)
    
    def update(self, instance, validated_data):
        password = validated_data.pop('password', None)
        user = super().update(instance, validated_data)

        if password:
            user.set_password(password)
            user.save()

        # return the `user` so it can be used by the `view` if required.
        return user


class AuthTokenSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(
        style={'input_type': 'password'},
        trim_whitespace=False
    )

    def validate(self, attrs):
        email = attrs.get('email')
        password = attrs.get('password')

        user = authenticate(request=None, username=email, password=password)

        if not user:
            msg = _('provided credentials dont match')
            raise serializers.ValidationError(msg, code='authorization')
        
        attrs['user'] = user
        return attrs
