import { useEffect, useState } from "react";

import {
  Link,
  useNavigate,
} from "react-router-dom";

import api from "../api/axios";

type Movie = {
  id: number;
  title: string;
  description: string;
  release_year: number;
  poster: string | null;
  average_rating: number | null;
  likes_count: number;
};

type User = {
  email: string;
};

export default function MoviesPage() {
  const [movies, setMovies] = useState<Movie[]>([]);
  const [user, setUser] =
    useState<User | null>(null);

  const [loading, setLoading] =
    useState(true);

  const navigate = useNavigate();

  useEffect(() => {
    async function fetchData() {
      try {
        const moviesResponse =
          await api.get("/movies/");

        setMovies(moviesResponse.data);

        try {
          const userResponse =
            await api.get("/user/me/");

          setUser(userResponse.data);
        } catch {
          setUser(null);
        }
      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    }

    fetchData();
  }, []);

  async function handleLike(movieId: number) {
    if (!user) {
      navigate("/");

      return;
    }

    try {
      const response = await api.post(
        `/movies/${movieId}/like/`
      );

      const liked = response.data.liked;

      setMovies((prevMovies) =>
        prevMovies.map((movie) => {
          if (movie.id !== movieId) {
            return movie;
          }

          return {
            ...movie,
            likes_count: liked
              ? movie.likes_count + 1
              : movie.likes_count - 1,
          };
        })
      );
    } catch (err) {
      console.error(err);
    }
  }

  function handleLogout() {
    localStorage.removeItem("token");

    setUser(null);

    navigate("/");
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-zinc-900 text-white p-8">
        Loading...
      </div>
    );
  }

  const username =
    user?.email.split("@")[0];

  return (
    <div className="min-h-screen bg-zinc-900 text-white p-8">
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-4xl font-bold">
          Movies
        </h1>

        <div className="flex items-center gap-4">
          {user ? (
            <>
              <p className="text-zinc-400">
                Hi, {username}
              </p>

              <button
                onClick={handleLogout}
                className="bg-zinc-800 px-4 py-2 rounded-lg hover:bg-zinc-700"
              >
                Logout
              </button>
            </>
          ) : (
            <button
              onClick={() => navigate("/")}
              className="bg-blue-600 px-4 py-2 rounded-lg hover:bg-blue-500"
            >
              Login
            </button>
          )}
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {movies.map((movie) => (
          <Link
            to={`/movies/${movie.id}`}
            key={movie.id}
            className="bg-zinc-800 rounded-xl overflow-hidden"
          >
            {movie.poster && (
              <img
                src={movie.poster}
                alt={movie.title}
                className="w-full h-96 object-cover"
              />
            )}

            <div className="p-6">
              <h2 className="text-3xl font-bold mb-2">
                {movie.title}
              </h2>

              <p className="text-zinc-400 mb-4">
                {movie.release_year}
              </p>

              <p className="text-zinc-300 mb-6">
                {movie.description}
              </p>

              <div className="flex justify-between items-center">
                <div>
                  ⭐ {movie.average_rating ?? "N/A"}
                </div>

                <button
                  onClick={(e) => {
                    e.preventDefault();

                    handleLike(movie.id);
                  }}
                  className="text-xl hover:scale-110 transition"
                >
                  ❤️ {movie.likes_count}
                </button>
              </div>
            </div>
          </Link>
        ))}
      </div>
    </div>
  );
}
