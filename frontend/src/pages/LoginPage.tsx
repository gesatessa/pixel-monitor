import {
  useState,
  useEffect,
} from "react";

import {
  useNavigate,
} from "react-router-dom";

import api from "../api/axios";

export default function LoginPage() {
  const navigate = useNavigate();

  const [isRegistering, setIsRegistering] =
    useState(false);

  const [email, setEmail] =
    useState("");

  const [password, setPassword] =
    useState("");

  const [loading, setLoading] =
    useState(false);

  const [error, setError] =
    useState("");

  useEffect(() => {
    const token =
      localStorage.getItem("token");

    if (token) {
      navigate("/movies");
    }
  }, [navigate]);

  async function handleSubmit(
    e: React.FormEvent
  ) {
    e.preventDefault();

    setLoading(true);
    setError("");

    try {
      if (isRegistering) {
        await api.post("/user/create/", {
          email,
          password,
        });
      }

      const response = await api.post(
        "/user/token/",
        {
          email,
          password,
        }
      );

      const token =
        response.data.token;

      localStorage.setItem(
        "token",
        token
      );

      navigate("/movies");
    } catch (err: any) {
      console.error(err);

      if (
        err.response?.data?.email
      ) {
        setError(
          err.response.data.email[0]
        );
      } else {
        setError(
          isRegistering
            ? "Registration failed"
            : "Invalid credentials"
        );
      }
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-zinc-900 text-white">
      <form
        onSubmit={handleSubmit}
        className="w-full max-w-sm bg-zinc-800 p-8 rounded-xl space-y-4"
      >
        <h1 className="text-3xl font-bold">
          {isRegistering
            ? "Register"
            : "Login"}
        </h1>

        <div>
          <label className="block mb-1">
            Email
          </label>

          <input
            type="email"
            value={email}
            onChange={(e) =>
              setEmail(
                e.target.value
              )
            }
            className="w-full p-3 rounded bg-zinc-700"
          />
        </div>

        <div>
          <label className="block mb-1">
            Password
          </label>

          <input
            type="password"
            value={password}
            onChange={(e) =>
              setPassword(
                e.target.value
              )
            }
            className="w-full p-3 rounded bg-zinc-700"
          />
        </div>

        {error && (
          <p className="text-red-400 text-sm">
            {error}
          </p>
        )}

        <button
          type="submit"
          disabled={loading}
          className="w-full bg-blue-600 hover:bg-blue-500 p-3 rounded font-semibold"
        >
          {loading
            ? "Loading..."
            : isRegistering
            ? "Register"
            : "Login"}
        </button>

        <button
          type="button"
          onClick={() =>
            setIsRegistering(
              !isRegistering
            )
          }
          className="w-full text-zinc-400 hover:text-white"
        >
          {isRegistering
            ? "Already have an account? Login"
            : "No account? Register"}
        </button>
      </form>
    </div>
  );
}
