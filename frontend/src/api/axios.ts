import axios from "axios";

const api = axios.create({
  // baseURL: "http://localhost:8000/api",
  baseURL: import.meta.env.VITE_API_URL || "/api",
});

// api.interceptors.request.use((config) => {
//   const token = localStorage.getItem("token");

//   if (token) {
//     config.headers.Authorization = `Token ${token}`;
//   }

//   return config;
// });

api.interceptors.request.use((config) => {
  const token = localStorage.getItem("token");

  const validToken =
    token &&
    token !== "undefined" &&
    token !== "null" &&
    token.trim() !== "";

  if (validToken) {
    config.headers.Authorization = `Token ${token}`;
  } else {
    delete config.headers.Authorization;
  }

  return config;
});

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem("token");
      delete api.defaults.headers.common.Authorization;
    }

    return Promise.reject(error);
  }
);

export default api;
